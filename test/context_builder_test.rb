$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'minitest/autorun'
require 'rgen/metamodel_builder'
require 'rtext/language'
require 'rtext/context_builder'

class ContextBuilderTest < MiniTest::Test 

module TestMM
  extend RGen::MetamodelBuilder::ModuleExtension
  class TestNode < RGen::MetamodelBuilder::MMBase
    has_attr 'text', String
    has_attr 'unlabled', String
    has_many_attr 'unlabled_array', String
    has_many_attr 'nums', Integer
    has_many_attr 'strings', String
    has_attr 'boolean', Boolean
    has_one 'related', TestNode
    has_many 'others', TestNode
    contains_many 'childs', TestNode, 'parent'
  end
end

def test_root
  c = build_context TestMM, <<-END
|
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false
  assert_nil(c.element)
end

def test_root2
  c = build_context TestMM, <<-END
|TestNode
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false
  assert_nil(c.element)
end

def test_root_in_cmd
  c = build_context TestMM, <<-END
Test|Node
  END
  assert_context c, :prefix => "Test", :feature => nil, :in_array => false, :in_block => false
  assert_nil(c.element)
end

def test_root_after_cmd
  c = build_context TestMM, <<-END
TestNode|
  END
  assert_context c, :prefix => "TestNode", :feature => nil, :in_array => false, :in_block => false
  assert_nil(c.element)
end

def test_root_after_cmd2
  c = build_context TestMM, <<-END
TestNode |
  END
  assert_context c, :prefix => "", :feature => "unlabled", :in_array => false, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
end

def test_root_in_lable
  c = build_context TestMM, <<-END
TestNode ot|hers:
  END
  assert_context c, :prefix => "ot", :feature => "unlabled", :in_array => false, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
end

def test_root_after_lable
  c = build_context TestMM, <<-END
TestNode others:|
  END
  assert_context c, :prefix => "", :feature => "others", :in_array => false, :in_block => false, :after_label => true
  assert(c.element.is_a?(TestMM::TestNode))
end

def test_root_after_lable2
  c = build_context TestMM, <<-END
TestNode others: |
  END
  assert_context c, :prefix => "", :feature => "others", :in_array => false, :in_block => false, :after_label => true
  assert(c.element.is_a?(TestMM::TestNode))
end

def test_root_after_lable_with_value
  c = build_context TestMM, <<-END
TestNode text: xx, others: |
  END
  assert_context c, :prefix => "", :feature => "others", :in_array => false, :in_block => false, :after_label => true
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("xx", c.element.text)
end

def test_root_after_lable_with_value_missing_comma
  c = build_context TestMM, <<-END
TestNode text: xx others: |
  END
  assert_context c, :prefix => "", :feature => "others", :in_array => false, :in_block => false, :after_label => true
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("xx", c.element.text)
end

def test_root_after_unlabled
  c = build_context TestMM, <<-END
TestNode "bla"| 
  END
  assert_context c, :prefix => "\"bla\"", :feature => "unlabled", :in_array => false, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_nil(c.element.unlabled)
end

def test_root_after_unlabled_string_with_comma
  c = build_context TestMM, <<-END
TestNode "a,b"| 
  END
  assert_context c, :prefix => "\"a,b\"", :feature => "unlabled", :in_array => false, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_nil(c.element.unlabled)
end

def test_root_after_unlabled_string_with_quoted_quote
  c = build_context TestMM, <<-END
TestNode "a,\\"b"| 
  END
  assert_context c, :prefix => "\"a,\\\"b\"", :feature => "unlabled", :in_array => false, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_nil(c.element.unlabled)
end

def test_root_after_unlabled_unclosed_string_with_comma
  c = build_context TestMM, <<-END
TestNode "a,b| 
  END
  assert_context c, :prefix => "\"a,b", :feature => "unlabled", :in_array => false, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_nil(c.element.unlabled)
end

def test_root_after_unlabled_no_quot
  c = build_context TestMM, <<-END
TestNode bla| 
  END
  assert_context c, :prefix => "bla", :feature => "unlabled", :in_array => false, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_nil(c.element.unlabled)
end

def test_root_after_unlabled2
  c = build_context TestMM, <<-END
TestNode "bla" | 
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false, :problem => :missing_comma 
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
end

def test_root_after_unlabled2_no_quot
  c = build_context TestMM, <<-END
TestNode bla | 
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false, :problem => :missing_comma
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
end

def test_root_after_unlabled_comma_no_quot
  c = build_context TestMM, <<-END
TestNode bla,| 
  END
  assert_context c, :prefix => "", :feature => "unlabled_array", :in_array => false, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
end

def test_root_after_unlabled_comma
  c = build_context TestMM, <<-END
TestNode "bla", | 
  END
  assert_context c, :prefix => "", :feature => "unlabled_array", :in_array => false, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
end

def test_root_after_unlabled_comma_no_ws
  c = build_context TestMM, <<-END
TestNode "bla",| 
  END
  assert_context c, :prefix => "", :feature => "unlabled_array", :in_array => false, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
end

def test_root_unlabled_array
  c = build_context TestMM, <<-END
TestNode "bla", [|
  END
  assert_context c, :prefix => "", :feature => "unlabled_array", :in_array => true, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
  assert_equal([], c.element.unlabled_array)
end

def test_root_unlabled_array_first_value
  c = build_context TestMM, <<-END
TestNode "bla", [a|
  END
  assert_context c, :prefix => "a", :feature => "unlabled_array", :in_array => true, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
  assert_equal([], c.element.unlabled_array)
end

def test_root_unlabled_array_first_value_quoted
  c = build_context TestMM, <<-END
TestNode "bla", ["a"|
  END
  assert_context c, :prefix => "\"a\"", :feature => "unlabled_array", :in_array => true, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
  assert_equal([], c.element.unlabled_array)
end

def test_root_unlabled_array_first_value_quoted_open
  c = build_context TestMM, <<-END
TestNode "bla", ["a|
  END
  assert_context c, :prefix => "\"a", :feature => "unlabled_array", :in_array => true, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
  assert_equal([], c.element.unlabled_array)
end

def test_root_unlabled_array_first_value_after_space
  c = build_context TestMM, <<-END
TestNode "bla", ["a" |
  END
  # although not having a comma in front is an error, we are already within a feature
  # due to the opening square bracket
  assert_context c, :prefix => "", :feature => "unlabled_array", :in_array => true, :in_block => false, :problem => :missing_comma
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
  assert_equal(["a"], c.element.unlabled_array)
end

def test_root_unlabled_array_first_value_after_comma
  c = build_context TestMM, <<-END
TestNode "bla", ["a",|
  END
  assert_context c, :prefix => "", :feature => "unlabled_array", :in_array => true, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
  assert_equal(["a"], c.element.unlabled_array)
end

def test_root_unlabled_array_second_value
  c = build_context TestMM, <<-END
TestNode "bla", ["a", b|
  END
  assert_context c, :prefix => "b", :feature => "unlabled_array", :in_array => true, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
  assert_equal(["a"], c.element.unlabled_array)
end

def test_root_unlabled_array_second_value_quoted
  c = build_context TestMM, <<-END
TestNode "bla", ["a", "b"|
  END
  assert_context c, :prefix => "\"b\"", :feature => "unlabled_array", :in_array => true, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
  assert_equal(["a"], c.element.unlabled_array)
end

def test_root_unlabled_array_second_value_quoted_open
  c = build_context TestMM, <<-END
TestNode "bla", ["a", "b|
  END
  assert_context c, :prefix => "\"b", :feature => "unlabled_array", :in_array => true, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
  assert_equal(["a"], c.element.unlabled_array)
end

def test_root_unlabled_array_second_value_after_comma
  c = build_context TestMM, <<-END
TestNode "bla", ["a", b,|
  END
  assert_context c, :prefix => "", :feature => "unlabled_array", :in_array => true, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
  assert_equal(["a", "b"], c.element.unlabled_array)
end

def test_root_unlabled_array_after_array
  c = build_context TestMM, <<-END
TestNode "bla", ["a", b]| 
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false, :problem => :missing_comma
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
  assert_equal(["a", "b"], c.element.unlabled_array)
end

def test_root_unlabled_array_after_array2
  c = build_context TestMM, <<-END
TestNode "bla", ["a", b] | 
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false, :problem => :missing_comma
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
  assert_equal(["a", "b"], c.element.unlabled_array)
end

def test_root_unlabled_array_after_array3
  c = build_context TestMM, <<-END
TestNode "bla", ["a", b],| 
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("bla", c.element.unlabled)
  assert_equal(["a", "b"], c.element.unlabled_array)
end

def test_root_labled_string_value
  c = build_context TestMM, <<-END
TestNode text: "a,b"| 
  END
  assert_context c, :prefix => "\"a,b\"", :feature => "text", :in_array => false, :in_block => false, :after_label => true
  assert(c.element.is_a?(TestMM::TestNode))
  assert_nil(c.element.text)
end

def test_root_labled_string_value2
  c = build_context TestMM, <<-END
TestNode text: "a,b" | 
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false, :problem => :missing_comma
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("a,b", c.element.text)
end

def test_root_labled_string_value3
  c = build_context TestMM, <<-END
TestNode text: "a,b",| 
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false
  assert(c.element.is_a?(TestMM::TestNode))
  assert_equal("a,b", c.element.text)
end

def test_root_labled_string_value_within
  c = build_context TestMM, <<-END
TestNode text: "a,b| 
  END
  assert_context c, :prefix => "\"a,b", :feature => "text", :in_array => false, :in_block => false, :after_label => true
  assert(c.element.is_a?(TestMM::TestNode))
  assert_nil(c.element.text)
end

def test_root_labled_string_value_within_no_ws
  c = build_context TestMM, <<-END
TestNode text:"a,b| 
  END
  assert_context c, :prefix => "\"a,b", :feature => "text", :in_array => false, :in_block => false, :after_label => true
  assert(c.element.is_a?(TestMM::TestNode))
  assert_nil(c.element.text)
end

def test_root_labled_string_value_no_quot
  c = build_context TestMM, <<-END
TestNode text: t| 
  END
  assert_context c, :prefix => "t", :feature => "text", :in_array => false, :in_block => false, :after_label => true
  assert(c.element.is_a?(TestMM::TestNode))
  assert_nil(c.element.text)
end

def test_root_labled_bool_value
  c = build_context TestMM, <<-END
TestNode boolean: t| 
  END
  assert_context c, :prefix => "t", :feature => "boolean", :in_array => false, :in_block => false, :after_label => true
  assert(c.element.is_a?(TestMM::TestNode))
  assert_nil(c.element.text)
end

def test_root_after_curly
  c = build_context TestMM, <<-END
TestNode {|
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false, :problem => :after_curly
  assert(c.element.is_a?(TestMM::TestNode))
end

def test_root_after_curly_no_ws
  c = build_context TestMM, <<-END
TestNode{|
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false, :problem => :after_curly
  assert(c.element.is_a?(TestMM::TestNode))
end

def test_in_cmd_after_cmd
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode |others: /dummy {
  END
  assert_context c, :prefix => "", :feature => "unlabled", :in_array => false, :in_block => false
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_after_cmd2
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode| nums: 3 {
  END
  assert_context c, :prefix => "TestNode", :feature => nil, :in_array => false, :in_block => true
  assert(c.element.is_a?(TestMM::TestNode))
end

def test_in_cmd_in_label
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode ot|hers: /dummy {
  END
  assert_context c, :prefix => "ot", :feature => "unlabled", :in_array => false, :in_block => false
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_after_label
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: |/dummy {
  END
  assert_context c, :prefix => "", :feature => "others", :in_array => false, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_in_label2
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others:| /dummy {
  END
  assert_context c, :prefix => "", :feature => "others", :in_array => false, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_after_label_no_ws
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others:|/dummy {
  END
  assert_context c, :prefix => "", :feature => "others", :in_array => false, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_in_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /du|mmy {
  END
  assert_context c, :prefix => "/du", :feature => "others", :in_array => false, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_in_value2
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy| {
  END
  assert_context c, :prefix => "/dummy", :feature => "others", :in_array => false, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_after_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy, |text: x {
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_after_value_no_ws
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy,|text: x {
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_after_value_no_ws2
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others:/dummy,|text: x {
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_after_value_directly_after_comma
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy,| text: x {
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_in_second_label
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy, te|xt: x {
  END
  assert_context c, :prefix => "te", :feature => nil, :in_array => false, :in_block => false
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_after_second_label
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy, text: |x {
  END
  assert_context c, :prefix => "", :feature => "text", :in_array => false, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_after_second_label_no_ws
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others:/dummy,text:|x {
  END
  assert_context c, :prefix => "", :feature => "text", :in_array => false, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_in_second_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy, text: x| {
  END
  assert_context c, :prefix => "x", :feature => "text", :in_array => false, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_in_second_value_no_ws
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others:/dummy,text:x| {
  END
  assert_context c, :prefix => "x", :feature => "text", :in_array => false, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_in_array
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: [|/dummy, text: x
  END
  assert_context c, :prefix => "", :feature => "others", :in_array => true, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_in_array_no_ws
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others:[|/dummy, text: x
  END
  assert_context c, :prefix => "", :feature => "others", :in_array => true, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_in_array_within_string_value_empty
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode strings: ["|
  END
  assert_context c, :prefix => "\"", :feature => "strings", :in_array => true, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_in_array_within_string_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode strings: ["a,b|
  END
  assert_context c, :prefix => "\"a,b", :feature => "strings", :in_array => true, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_in_array_within_second_string_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode strings: ["a,b", "c,d|
  END
  assert_context c, :prefix => "\"c,d", :feature => "strings", :in_array => true, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_in_array_after_second_string_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode strings: ["a,b", "c,d"|
  END
  assert_context c, :prefix => "\"c,d\"", :feature => "strings", :in_array => true, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_equal(["a,b"], c.element.strings)
end

def test_in_cmd_in_array_after_second_string_value2
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode strings: ["a,b", "c,d" |
  END
  assert_context c, :prefix => "", :feature => "strings", :in_array => true, :in_block => false, :problem => :missing_comma, :after_label => true
  assert_simple_model(c.element)
  assert_equal(["a,b", "c,d"], c.element.strings)
end

def test_in_cmd_in_array_after_string_array
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode strings: ["a,b", "c,d"]|
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false, :problem => :missing_comma
  assert_simple_model(c.element)
  assert_equal(["a,b", "c,d"], c.element.strings)
end

def test_in_cmd_in_array_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: [/d|ummy, text: x
  END
  assert_context c, :prefix => "/d", :feature => "others", :in_array => true, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_in_array_value_no_ws
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others:[/d|ummy, text: x
  END
  assert_context c, :prefix => "/d", :feature => "others", :in_array => true, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_after_array_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: [/dummy,| text: x
  END
  assert_context c, :prefix => "", :feature => "others", :in_array => true, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_after_array_value_no_ws
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others:[/dummy,| text: x
  END
  assert_context c, :prefix => "", :feature => "others", :in_array => true, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_in_second_array_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: [/dummy, /dom|my
  END
  assert_context c, :prefix => "/dom", :feature => "others", :in_array => true, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_in_second_array_value_no_ws
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: [/dummy,/dom|my
  END
  assert_context c, :prefix => "/dom", :feature => "others", :in_array => true, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_in_second_array_value_no_ws2
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others:[/dummy,/dom|my
  END
  assert_context c, :prefix => "/dom", :feature => "others", :in_array => true, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_after_array
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: [/dummy, /dommy], |
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy", "/dommy"])
end

def test_in_cmd_after_array_no_ws
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others:[/dummy,/dommy],|
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => false
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy", "/dommy"])
end

def test_in_cmd_after_array2
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: [/dummy, /dommy], nums: |
  END
  assert_context c, :prefix => "", :feature => "nums", :in_array => false, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy", "/dommy"])
end

def test_in_cmd_after_array2_no_ws
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others:[/dummy,/dommy],nums:|
  END
  assert_context c, :prefix => "", :feature => "nums", :in_array => false, :in_block => false, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy", "/dommy"])
end

def test_in_cmd_boolean_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode boolean: t|
  END
  assert_context c, :prefix => "t", :feature => "boolean", :in_array => false, :in_block => false, :after_label => true
  assert_simple_model(c.element)
end

def test_below_single_label
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy {
        childs:
          | 
  END
  assert_context c, :prefix => "", :feature => "childs", :in_array => false, :in_block => true, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_below_single_label_started_command
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy {
        childs:
          Tes| 
  END
  assert_context c, :prefix => "Tes", :feature => "childs", :in_array => false, :in_block => true, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_below_single_label_after_command
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy {
        childs:
          TestNode | 
  END
  assert_context c, :prefix => "", :feature => "unlabled", :in_array => false, :in_block => false
  assert_equal [3], c.element.parent.parent.nums
end

def test_below_multi_label
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy {
        childs: [
          | 
  END
  assert_context c, :prefix => "", :feature => "childs", :in_array => true, :in_block => true, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_below_multi_label_started_command
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy {
        childs: [
          Tes| 
  END
  assert_context c, :prefix => "Tes", :feature => "childs", :in_array => true, :in_block => true, :after_label => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_below_multi_label_after_command
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy {
        childs: [
          TestNode | 
  END
  assert_context c, :prefix => "", :feature => "unlabled", :in_array => false, :in_block => false
  assert_equal [3], c.element.parent.parent.nums
end

def test_in_new_line
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy {
        |
  END
  assert_context c, :prefix => "", :feature => nil, :in_array => false, :in_block => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_new_line_started_command
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy {
        Tes|
  END
  assert_context c, :prefix => "Tes", :feature => nil, :in_array => false, :in_block => true
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def assert_context(c, options)
  assert_equal(options[:prefix], c.prefix)
  assert_equal(options[:in_array], c.position.in_array)
  assert_equal(options[:in_block], c.position.in_block)
  assert_equal((options[:after_label] || false), c.position.after_label)
  if options[:problem]
    assert_equal(options[:problem], c.problem)
  else
    assert_nil(c.problem)
  end
  if options[:feature]
    assert_equal(options[:feature], c.feature.name)
  else
    assert_nil(c.feature)
  end
end

def assert_simple_model(c)
  assert c.is_a?(TestMM::TestNode)
  assert c.parent.is_a?(TestMM::TestNode)
  assert_equal [3], c.parent.nums
  assert c.parent.parent.is_a?(TestMM::TestNode)
  assert_equal "a", c.parent.parent.text
end

def assert_other_values(c, values)
  assert_equal values, c.others.collect{|v| v.targetIdentifier}
end

def build_context(mm, text)
  context_lines = text.split("\n")
  pos_in_line = context_lines.last.index("|")
  context_lines.last.sub!("|", "")
  lang = RText::Language.new(mm.ecore, 
    :root_classes => mm.ecore.eAllClasses,
    :unlabled_arguments => lambda {|c| ["unlabled", "unlabled_array"]})
  RText::ContextBuilder.build_context(lang, context_lines, pos_in_line)
end

end

