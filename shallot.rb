# shallot: a lexer/parser for Gherkin.
# Copyright 2011 Noble Samurai.
# Bugs to Anneli Cuss <celtic@sairyx.org>.
#
# shallot can lex and parse just enough Gherkin to give you:
#
# {:feature=>"The name of the feature",
#  :background=>
#   ["\t\tEach step in the background",
#    "\t\tBut without any additional parsing",
#    "\t\tOr validation"],
#  :scenarios=>
#   [{:name=>"And each scenario",
#     :outline=>false,
#     :tags=>["shallot", "regression", "bug"],
#     :contents=>
#      ["\t\tWith tags, including those inherited",
#       "\t\tFrom the feature level tags"]},
#    {:name=>"As well as scenario outlines",
#     :outline=>true,
#     :tags=>["shallot", "feature"],
#     :contents=>
#      ["\t\tWith support for the following",
#       "\t\t\t\"\"\"",
#       "\t\t\tlong-quoted",
#       "\t\t\tsections",
#       "\t\t\t\"\"\"",
#       "\t\tWhile no extra <kind> for examples",
#       "\t\tExamples:",
#       "\t\t\t| kind    |",
#       "\t\t\t| parsing |",
#       "\t\t\t| lexing  |"]}]}
#
# The above results from calling Shallot.parse(f), where f is an open File
# handle on the following feature file:
#
# @shallot
# Feature: The name of the feature
# 	This gets completely ignored.
# 
# 	Background:
# 		Each step in the background
# 		But without any additional parsing
# 		Or validation
# 
# 	@regression @bug
# 	Scenario: And each scenario
# 		With tags, including those inherited
# 		From the feature level tags
# 
# 	@feature
# 	Scenario Outline: As well as scenario outlines
# 		With support for the following
# 			"""
# 			long-quoted
# 			sections
# 			"""
# 		While no extra <kind> for examples
# 
# 		Examples:
# 			| kind    |
# 			| parsing |
# 			| lexing  |

class Shallot
    class Error < ::StandardError; end

    def self.parse f
	parser = new
	f.each_line {|l| parser.parse l}
	parser.eof

	{
	    feature: parser.feature,
	    background: parser.background,
	    scenarios: parser.scenarios,
	}
    end

    def initialize
	@state = :opening
	@file_tags = []
	@scenario_tags = []
	@qqq = nil
	@scenario = nil

	@background = []
	@scenarios = []
	@feature = nil
    end

    attr_reader :background, :scenarios, :feature

    def parse l
	# Check some conditions that should be (more or less) invariant across
	# a feature file.
	
	if @qqq.nil? and %w{''' """}.include? l.strip
	    # Start triple-quote.
	    @qqq = l.strip

	elsif @qqq == l.strip
	    # End triple-quote.
	    @qqq = nil

	elsif @qqq.nil? and [nil, ?#].include? l.strip[0]
	    # Blank or comment; outside triple-quote.
	    return
	end

	# Use state.
	
	method = :"parse_#@state"
	raise Error, "no parser for #@state" unless respond_to? method
	send method, l
    end

    def eof
	method = :"eof_#@state"
	raise Error, "no eof handler for #@state" unless respond_to? method
	send method
    end

    protected

    def parse_opening l
	if tags = parse_tag_line(l)
	    # Tags on beginning of file.
	    @file_tags.concat tags
	
	elsif feature = parse_feature_start(l)
	    # Start feature.
	    @state = :feature
	    @feature = feature
	
	else
	    # There shouldn't be anything else in here.
	    raise Error, "unexpected line before feature start"
	end
    end

    def parse_feature l
	if is_background_start? l
	    # Start background.
	    @state = :background

	    raise Error, "tags before background" if @scenario_tags.length > 0
	
	elsif scenario = parse_scenario_start(l)
	    # Start scenario (outline).
	    start_scenario scenario

	elsif tags = parse_tag_line(l)
	    # Tags; presumably before a scenario.
	    @scenario_tags.concat tags

	else
	    # Most likely part of the "As a .." prelude. Ignore.
	end
    end

    def parse_background l
	if @qqq.nil? and tags = parse_tag_line(l)
	    # Tags; presumably before a scenario.
	    @scenario_tags.concat tags

	elsif @qqq.nil? and scenario = parse_scenario_start(l)
	    # Start scenario (outline).
	    start_scenario scenario
	
	else
	    # Any other step; part of the background.
	    @background << l.gsub(/\n$/, "")
	end
    end

    def parse_scenario l
	if @qqq.nil? and tags = parse_tag_line(l)
	    # Tags; presumably before a scenario.
	    @scenario_tags.concat tags

	elsif @qqq.nil? and scenario = parse_scenario_start(l)
	    # Start scenario (outline).
	    start_scenario scenario

	else
	    # Any other step; part of the scenario (outline).
	    @scenario[:contents] << l.gsub(/\n$/, "")
	end
    end

    def eof_scenario
	@scenarios << @scenario
    end

    def start_scenario scenario
	@state = :scenario
	@scenarios << @scenario if @scenario

	@scenario = {
	    name: scenario[:name],
	    outline: scenario[:outline],
	    tags: (@file_tags + @scenario_tags).uniq,
	    contents: []
	}

	@scenario_tags = []
    end

    private

    def parse_tag_line l
	if (tags = l.strip.split).all? {|w| w[0] == ?@}
	    tags.map {|t| t[1..-1].downcase}
	end
    end

    def parse_feature_start l
	$1.strip if l.strip =~ /^feature:(.*)$/i
    end

    def is_background_start? l
	l.strip.downcase == "background:"
    end

    def parse_scenario_start l
	if l.strip =~ /^scenario( outline)?:(.*)$/i
	    {name: $2.strip, outline: !!$1} 
	end
    end
end

# vim: set sw=4 ts=8 noet cc=80:
