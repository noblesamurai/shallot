# shallot
#### <span style="color: #333">a lexer/parser for Gherkin</span>

## introduction

shallot can lex and parse just enough Gherkin to give you:

    {:feature=>"The name of the feature",
     :background=>
      ["\t\tEach step in the background",
       "\t\tBut without any additional parsing",
       "\t\tOr validation"],
     :scenarios=>
      [{:name=>"And each scenario",
	:outline=>false,
	:tags=>["shallot", "regression", "bug"],
	:contents=>
	 ["\t\tWith tags, including those inherited",
	  "\t\tFrom the feature level tags"]},
       {:name=>"As well as scenario outlines",
	:outline=>true,
	:tags=>["shallot", "feature"],
	:contents=>
	 ["\t\tWith support for the following",
	  "\t\t\t\"\"\"",
	  "\t\t\tlong-quoted",
	  "\t\t\tsections",
	  "\t\t\t\"\"\"",
	  "\t\tWhile no extra <kind> for examples",
	  "\t\tExamples:",
	  "\t\t\t| kind    |",
	  "\t\t\t| parsing |",
	  "\t\t\t| lexing  |"]}]}

The above results from calling Shallot.parse(f), where f is an open File
handle on the following feature file:

    @shallot
    Feature: The name of the feature
	    This gets completely ignored.

	    Background:
		    Each step in the background
		    But without any additional parsing
		    Or validation

	    @regression @bug
	    Scenario: And each scenario
		    With tags, including those inherited
		    From the feature level tags

	    @feature
	    Scenario Outline: As well as scenario outlines
		    With support for the following
			    """
			    long-quoted
			    sections
			    """
		    While no extra <kind> for examples

		    Examples:
			    | kind    |
			    | parsing |
			    | lexing  |

## contributors

 - [Anneli Cuss](http://github.com/celtic) with [Noble Samurai](http://github.com/noblesamurai)
 - You?

## license

Copyright 2011 Noble Samurai

shallot is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

shallot is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with shallot.  If not, see http://www.gnu.org/licenses/.
