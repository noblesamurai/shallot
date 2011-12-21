# shallot: a lexer/parser for Gherkin.
# Copyright 2011 Noble Samurai
# Bugs to Anneli Cuss <a@unnali.com>.
#
# shallot is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# shallot is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with
# shallot.  If not, see http://www.gnu.org/licenses/.

# shallot exposes only one class; Shallot.  A Shallot instance encompasses the
# state of the parsing operation, which can be advanced by feeding it lines of
# gherkin.  That sounded weird.  The Shallot class also exposes methods to wrap
# the instance, allowing you to quickly serve parsed feature files.
class Shallot

  # All errors from shallot are raised as a Shallot::Error.  Details are in the
  # message.
  class Error < ::StandardError; end

  # Parses +file+ in its entirety (by creating a new Shallot instance), and
  # returns a hash with +:feature+, +:background+ and +:scenarios+ keys as for
  # the Shallot instance object.  +file+ only needs to implement +each_line+.
  # If an error occurs, Shallot::Error will be thrown.
  def self.parse file
    parser = new
    file.each_line {|line| parser.parse line}
    parser.eof!

    {
      feature:    parser.feature,
      background: parser.background,
      scenarios:  parser.scenarios,
    }
  end

  # Creates a fresh Shallot instance.
  def initialize
    @state = :opening
    @file_tags = []
    @scenario_tags = []
    @qqq = nil
    @scenario = nil
    @line = 0

    @background = []
    @scenarios = []
    @feature = nil
  end

  # The name of the feature, as specified on the "Feature:" line.
  attr_reader :feature

  # A list of strings; the lines comprising the Background steps.
  attr_reader :background

  # A list of hashes for each Scenario or Scenario Outline; the hash contains:
  # * +:name+: the name as given on the "Scenario:" or "Scenario Outline:" line
  # * +:outline+: +true+ if this is a Scenario Outline, +false+ if Scenario
  # * +:tags+: the list of tags for this scenario (sans "@"), including
  #   feature-wide tags
  # * +:contents+: the list of steps (one string per line), including all
  #   whitespace, tables, etc.
  attr_reader :scenarios

  # Parses the next line, +line+.  Parse or internal errors may cause
  # Shallot::Error to be thrown.
  def parse line
    # Check some conditions that should be (more or less) invariant across
    # a feature file.
    @line += 1
    
    if @qqq.nil? and %w{''' """}.include? line.strip
      # Start triple-quote.
      @qqq = line.strip

    elsif @qqq == line.strip
      # End triple-quote.
      @qqq = nil

    elsif @qqq.nil? and [nil, ?#].include? line.strip[0]
      # Blank or comment; outside triple-quote.
      return
    end

    # Use state.
    
    method = :"parse_#@state"
    raise Error, "no parser for #@state" unless respond_to? method
    send method, line
  end

  # Signals to the parser that the end of the file has been reached.  This may
  # throw Shallot::Error if EOF wasn't expected in its current state.
  def eof!
    method = :"eof_#@state"
    raise Error, "no eof handler for #@state" unless respond_to? method
    send method
  end

  protected

  # Parses +line+ before we've seen the opening "Feature:" line.
  def parse_opening line
    if tags = parse_tag_line(line)
      # Tags on beginning of file.
      @file_tags.concat tags
    
    elsif feature = parse_feature_start(line)
      # Start feature.
      @state = :feature
      @feature = feature
    
    else
      # There shouldn't be anything else in here.
      raise Error, "unexpected line before feature start"
    end
  end

  # Parses +line+ after we've seen "Feature:", but before the Background or any
  # scenario (outline).
  def parse_feature line
    if is_background_start? line
      # Start background.
      @state = :background

      raise Error, "tags before background" if @scenario_tags.length > 0
    
    elsif scenario = parse_scenario_start(line)
      # Start scenario (outline).
      start_scenario scenario

    elsif tags = parse_tag_line(line)
      # Tags; presumably before a scenario.
      @scenario_tags.concat tags

    else
      # Most likely part of the "As a .." prelude. Ignore.
    end
  end

  # Parses +line+ after we've seen "Background:", but before any scenario.
  def parse_background line
    if @qqq.nil? and tags = parse_tag_line(line)
      # Tags; presumably before a scenario.
      @scenario_tags.concat tags

    elsif @qqq.nil? and scenario = parse_scenario_start(line)
      # Start scenario (outline).
      start_scenario scenario
    
    else
      # Any other step; part of the background.
      @background << line.gsub(/\n$/, "")
    end
  end

  # Parses +line+ after we've seen "Scenario:" or "Scenario Outline:".
  def parse_scenario line
    if @qqq.nil? and tags = parse_tag_line(line)
      # Tags; presumably before a scenario.
      @scenario_tags.concat tags

    elsif @qqq.nil? and scenario = parse_scenario_start(line)
      # Start scenario (outline).
      start_scenario scenario

    else
      # Any other step; part of the scenario (outline).
      @scenario[:contents] << line.gsub(/\n$/, "")
    end
  end

  # Handles EOF after having seen "Scenario:" or "Scenario Outline:".
  def eof_scenario
    @scenarios << @scenario
  end

  # Moves to the scenario parsing state with the ad-hoc information in
  # +scenario+ from +parse_scenario_start+.
  def start_scenario scenario
    @state = :scenario
    @scenarios << @scenario if @scenario

    @scenario = {
      name:     scenario[:name],
      outline:  scenario[:outline],
      tags:     (@file_tags + @scenario_tags).uniq,
      contents: [],
      line:     @line,
    }

    @scenario_tags = []
  end

  private

  # Parses a line of tags, +line+, returning a list of downcased tags sans "@".
  # Returns +nil+ if the line didn't contain only tags (and at least one).
  def parse_tag_line line
    if (tags = line.strip.split).all? {|w| w[0] == ?@}
      tags.map {|t| t[1..-1].downcase}
    end
  end

  # Parses a "Feature:" line, +line+, returning the title on the line, or +nil+
  # if it wasn't a feature line at all.
  def parse_feature_start line
    $1.strip if line.strip =~ /^feature:(.*)$/i
  end

  # Returns +true+ if +line+ is a "Background:" line.
  def is_background_start? line
    line.strip.downcase == "background:"
  end

  # Parses a scenario (outline) starting line, +line+, returning a hash with
  # +:name+ containing the title given on the line, and +:outline+ with +true+
  # if it was "Scenario Outline:", and +false+ if "Scenario:".  If it wasn't a
  # scenario starting line, returns +nil+.
  def parse_scenario_start line
    if line.strip =~ /^scenario( outline)?:(.*)$/i
      {name: $2.strip, outline: !!$1} 
    end
  end
end

# vim: set sw=2 ts=2 et cc=80:
