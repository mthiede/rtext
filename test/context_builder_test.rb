$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/metamodel_builder'
require 'rtext/language'
require 'rtext/context_builder'

class ContextBuilderTest < Test::Unit::TestCase

module TestMM
  extend RGen::MetamodelBuilder::ModuleExtension
  class TestNode < RGen::MetamodelBuilder::MMBase
    has_attr 'text', String
    has_many_attr 'nums', Integer
    has_one 'related', TestNode
    has_many 'others', TestNode
    contains_many 'childs', TestNode, 'parent'
  end
end

def test_in_cmd_after_cmd
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode |others: /dummy {
  END
  assert_equal("", c.prefix)
  assert_nil(c.feature)
  assert(!c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_in_label
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode ot|hers: /dummy {
  END
  assert_equal("ot", c.prefix)
  assert_nil(c.feature)
  assert(!c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_in_label2
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others:| /dummy {
  END
  assert_equal("", c.prefix)
  assert_equal("others", c.feature.name)
  assert(!c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_after_label
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: |/dummy {
  END
  assert_equal("", c.prefix)
  assert_equal("others", c.feature.name)
  assert(!c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_in_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /du|mmy {
  END
  assert_equal("/du", c.prefix)
  assert_equal("others", c.feature.name)
  assert(!c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_in_value2
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy| {
  END
  assert_equal("/dummy", c.prefix)
  assert_equal("others", c.feature.name)
  assert(!c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_after_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy, |text: x {
  END
  assert_equal("", c.prefix)
  assert_nil(c.feature)
  assert(!c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_in_second_label
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy, te|xt: x {
  END
  assert_equal("te", c.prefix)
  assert_nil(c.feature)
  assert(!c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_after_second_label
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy, text: |x {
  END
  assert_equal("", c.prefix)
  assert_equal("text", c.feature.name)
  assert(!c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_in_second_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy, text: x| {
  END
  assert_equal("x", c.prefix)
  assert_equal("text", c.feature.name)
  assert(!c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_in_array
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: [|/dummy, text: x
  END
  assert_equal("", c.prefix)
  assert_equal("others", c.feature.name)
  assert(c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_in_array_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: [/d|ummy, text: x
  END
  assert_equal("/d", c.prefix)
  assert_equal("others", c.feature.name)
  assert(c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, [])
end

def test_in_cmd_after_array_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: [/dummy,| text: x
  END
  assert_equal("", c.prefix)
  assert_equal("others", c.feature.name)
  assert(c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_in_second_array_value
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: [/dummy, /dom|my
  END
  assert_equal("/dom", c.prefix)
  assert_equal("others", c.feature.name)
  assert(c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_cmd_after_array
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: [/dummy, /dommy], |
  END
  assert_equal("", c.prefix)
  assert_nil(c.feature)
  assert(!c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy", "/dommy"])
end

def test_in_cmd_after_array2
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: [/dummy, /dommy], nums: |
  END
  assert_equal("", c.prefix)
  assert_equal("nums", c.feature.name)
  assert(!c.in_array)
  assert(!c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy", "/dommy"])
end

def test_below_single_label
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy {
        childs:
          | 
  END
  assert_equal("", c.prefix)
  assert_equal("childs", c.feature.name)
  assert(!c.in_array)
  assert(c.in_block)
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
  assert_equal("Tes", c.prefix)
  assert_equal("childs", c.feature.name)
  assert(!c.in_array)
  assert(c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_below_multi_label
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy {
        childs: [
          | 
  END
  assert_equal("", c.prefix)
  assert_equal("childs", c.feature.name)
  assert(c.in_array)
  assert(c.in_block)
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
  assert_equal("Tes", c.prefix)
  assert_equal("childs", c.feature.name)
  assert(c.in_array)
  assert(c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
end

def test_in_new_line
  c = build_context TestMM, <<-END
  TestNode text: a {
    TestNode nums: 3 {
      TestNode others: /dummy {
        |
  END
  assert_equal("", c.prefix)
  assert_nil(c.feature)
  assert(!c.in_array)
  assert(c.in_block)
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
  assert_equal("Tes", c.prefix)
  assert_nil(c.feature)
  assert(!c.in_array)
  assert(c.in_block)
  assert_simple_model(c.element)
  assert_other_values(c.element, ["/dummy"])
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
  lang = RText::Language.new(mm.ecore, :root_classes => mm.ecore.eAllClasses)
  RText::ContextBuilder.build_context_element(lang, context_lines, pos_in_line)
end

end

