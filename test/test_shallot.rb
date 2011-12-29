require 'helper'

class TestShallot < Test::Unit::TestCase
  should "parse a feature with all the trimmings correctly" do
    assert_equal Shallot.parse($feature), $parsed
  end
end

$feature = <<FEATURE
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
FEATURE

$parsed =
  {:feature=>"The name of the feature",
   :background=>
    ["        Each step in the background",
     "        But without any additional parsing",
     "        Or validation",
     ""],
   :scenarios=>
    [{:name=>"And each scenario",
      :outline=>false,
      :tags=>["shallot", "regression", "bug"],
      :contents=>
       ["        With tags, including those inherited",
        "        From the feature level tags",
        ""],
      :line=>11},
     {:name=>"As well as scenario outlines",
      :outline=>true,
      :tags=>["shallot", "feature"],
      :contents=>
       ["        With support for the following",
        "            \"\"\"",
        "            long-quoted",
        "            sections",
        "            \"\"\"",
        "        While no extra <kind> for examples",
        "",
        "        Examples:",
        "            | kind    |",
        "            | parsing |",
        "            | lexing  |"],
      :line=>16}]}
# vim: set sw=2 ts=8 et cc=80:
