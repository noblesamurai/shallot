# shallot: a lexer/parser for Gherkin.
# Copyright 2011 Noble Samurai.
# Bugs to Anneli Cuss <celtic@sairyx.org>.
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
# shallot.	If not, see http://www.gnu.org/licenses/.

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
		@line = 0

		@background = []
		@scenarios = []
		@feature = nil
	end

	attr_reader :background, :scenarios, :feature

	def parse l
		# Check some conditions that should be (more or less) invariant across
		# a feature file.
		@line += 1
		
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
			contents: [],
			line: @line,
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

# vim: set sw=4 ts=4 noet cc=80:
