$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'minitest/autorun'
require 'rgen/metamodel_builder'
require 'rtext/language'
require 'rtext/context_builder'
require 'rtext/default_completer'

class CompleterTest < MiniTest::Test

module TestMM
  extend RGen::MetamodelBuilder::ModuleExtension
  class TestNode2 < RGen::MetamodelBuilder::MMBase
    has_attr 'text', String
    has_attr 'unlabled', String
  end
  class TestNode3 < RGen::MetamodelBuilder::MMBase
  end
  class TestNode < RGen::MetamodelBuilder::MMBase
    has_attr 'text', String
    has_attr 'unlabled1', String
    has_attr 'unlabled2', Integer
    has_many_attr 'nums', Integer
    has_one 'related', TestNode
    has_many 'others', TestNode
    contains_many 'childs', TestNode, 'parent'
    contains_one 'child2RoleA', TestNode2, 'parentA'
    contains_many 'child2RoleB', TestNode2, 'parentB'
    contains_one_uni 'testNode3', TestNode3
  end
  SomeEnum = RGen::MetamodelBuilder::DataTypes::Enum.new(
    :name => "SomeEnum", :literals => [:A, :B, :'non-word*chars'])
  class TestNode3 < RGen::MetamodelBuilder::MMBase
    has_attr 'bool', Boolean
    has_attr 'float', Float
    has_attr 'enum', SomeEnum
  end
  class TextNode < RGen::MetamodelBuilder::MMBase
  end
end

def test_after_command
  options = complete TestMM, <<-END
TestNode |
  END
  assert_options([
    ["\"\"", "[unlabled1] <EString>"],
    ["text:", "<EString>"],
    ["nums:", "<EInt>"],
    ["related:", "<TestNode>"],
    ["others:", "<TestNode>"]
  ], options)
end

def test_lable_prefix
  options = complete TestMM, <<-END
TestNode t|
  END
  assert_options([
    ["\"\"", "[unlabled1] <EString>"],
    ["text:", "<EString>"],
    ["nums:", "<EInt>"],
    ["related:", "<TestNode>"],
    ["others:", "<TestNode>"]
  ], options)
end

def test_lable_within
  options = complete TestMM, <<-END
TestNode t|ext
  END
  assert_options([
    ["\"\"", "[unlabled1] <EString>"],
    ["text:", "<EString>"],
    ["nums:", "<EInt>"],
    ["related:", "<TestNode>"],
    ["others:", "<TestNode>"]
  ], options)
end

def test_unlabled_prefix
  options = complete TestMM, <<-END
TestNode u|
  END
  assert_options([
    ["\"\"", "[unlabled1] <EString>"],
    ["text:", "<EString>"],
    ["nums:", "<EInt>"],
    ["related:", "<TestNode>"],
    ["others:", "<TestNode>"]
  ], options)
end

def test_after_labled_value
  options = complete TestMM, <<-END
TestNode nums: 1, |
  END
  assert_options([
    ["text:", "<EString>"],
    ["related:", "<TestNode>"],
    ["others:", "<TestNode>"]
  ], options)
end

def test_after_labled_value_directly_after_comma
  options = complete TestMM, <<-END
TestNode nums: 1,|
  END
  assert_options([
    ["text:", "<EString>"],
    ["related:", "<TestNode>"],
    ["others:", "<TestNode>"]
  ], options)
end

def test_after_second_labled_value_directly_after_comma
  options = complete TestMM, <<-END
TestNode nums: 1, text: "a",|
  END
  assert_options([
    ["related:", "<TestNode>"],
    ["others:", "<TestNode>"]
  ], options)
end

def test_after_unlabled_value
  options = complete TestMM, <<-END
TestNode "bla", |
  END
  assert_options([
    ["0", "[unlabled2] <EInt>"],
    ["text:", "<EString>"],
    ["nums:", "<EInt>"],
    ["related:", "<TestNode>"],
    ["others:", "<TestNode>"]
  ], options)
end

def test_after_unlabled_value_directly_after_comma
  options = complete TestMM, <<-END
TestNode "bla",|
  END
  assert_options([
    ["0", "[unlabled2] <EInt>"],
    ["text:", "<EString>"],
    ["nums:", "<EInt>"],
    ["related:", "<TestNode>"],
    ["others:", "<TestNode>"]
  ], options)
end

def test_after_unlabled_value2
  options = complete TestMM, <<-END
TestNode "bla", 1, |
  END
  assert_options([
    ["text:", "<EString>"],
    ["nums:", "<EInt>"],
    ["related:", "<TestNode>"],
    ["others:", "<TestNode>"]
  ], options)
end

def test_after_unlabled_value3
  options = complete TestMM, <<-END
TestNode "bla", 1,|
  END
  assert_options([
    ["text:", "<EString>"],
    ["nums:", "<EInt>"],
    ["related:", "<TestNode>"],
    ["others:", "<TestNode>"]
  ], options)
end

def test_after_array
  options = complete TestMM, <<-END
TestNode nums: [1, 2], |
  END
  assert_options([
    ["text:", "<EString>"],
    ["related:", "<TestNode>"],
    ["others:", "<TestNode>"]
  ], options)
end

def test_after_array_direct
  options = complete TestMM, <<-END
TestNode nums: [1, 2]|
  END
  assert_options([
  ], options)
end

def test_value_int
  options = complete TestMM, <<-END
TestNode nums: | 
  END
  assert_options([
    ["0", "<EInt>"],
  ], options)
end

def test_value_int_part
  options = complete TestMM, <<-END
TestNode nums: 0| 
  END
  assert_options([
    ["0", "<EInt>"]
  ], options)
end

def test_value_boolean
  options = complete TestMM, <<-END
TestNode3 bool: | 
  END
  assert_options([
    ["true", "<EBoolean>"],
    ["false", "<EBoolean>"],
  ], options)
end

def test_value_boolean_part
  options = complete TestMM, <<-END
TestNode3 bool: t| 
  END
  assert_options([
    ["true", "<EBoolean>"],
    ["false", "<EBoolean>"],
  ], options)
end

def test_value_boolean_full
  options = complete TestMM, <<-END
TestNode3 bool: true| 
  END
  assert_options([
    ["true", "<EBoolean>"],
    ["false", "<EBoolean>"],
  ], options)
end

def test_value_float
  options = complete TestMM, <<-END
TestNode3 float: | 
  END
  assert_options([
    ["0.0", "<EFloat>"],
  ], options)
end

def test_value_float_part
  options = complete TestMM, <<-END
TestNode3 float: 0| 
  END
  assert_options([
    ["0.0", "<EFloat>"],
  ], options)
end

def test_value_float_full
  options = complete TestMM, <<-END
TestNode3 float: 0.0| 
  END
  assert_options([
    ["0.0", "<EFloat>"],
  ], options)
end

def test_value_enum
  options = complete TestMM, <<-END
TestNode3 enum: | 
  END
  assert_options([
    ["A", "<SomeEnum>"],
    ["B", "<SomeEnum>"],
    ["\"non-word*chars\"", "<SomeEnum>"]
  ], options)
end

def test_value_enum_part
  options = complete TestMM, <<-END
TestNode3 enum: A| 
  END
  assert_options([
    ["A", "<SomeEnum>"],
    ["B", "<SomeEnum>"],
    ["\"non-word*chars\"", "<SomeEnum>"]
  ], options)
end

def test_array_value
  options = complete TestMM, <<-END
TestNode nums: [|
  END
  assert_options([
    ["0", "<EInt>"],
  ], options)
end

def test_array_value2
  options = complete TestMM, <<-END
TestNode nums: [1,|
  END
  assert_options([
    ["0", "<EInt>"],
  ], options)
end

def test_reference_value
  options = complete(TestMM, %Q(\
TestNode related: |\
  ), lambda { |r| [
    RText::DefaultCompleter::CompletionOption.from_text_extra("A", "a"),
    RText::DefaultCompleter::CompletionOption.from_text_extra("B", "b") ] })
  assert_options([
    ["A", "a"],
    ["B", "b"],
  ], options)
end

def test_reference_value_part
  options = complete(TestMM, %Q(\
TestNode related: /My/|\
  ), lambda { |r| [
    RText::DefaultCompleter::CompletionOption.from_text_extra("/My/Target", "a"),
    RText::DefaultCompleter::CompletionOption.from_text_extra("/MyOther/Target", "b") ] })
  assert_options([
    ["/My/Target", "a"],
    ["/MyOther/Target", "b"]
  ], options)
end

def test_reference_value_no_ref_completion_provider
  options = complete TestMM, <<-END
TestNode related: |
  END
  assert_options([
  ], options)
end

def test_reference_value_in_array
  options = complete(TestMM, %Q(\
TestNode others: |
), lambda { |r| [
    RText::DefaultCompleter::CompletionOption.from_text_extra("A", "a"),
    RText::DefaultCompleter::CompletionOption.from_text_extra("B", "b") ] })
  assert_options([
    ["A", "a"],
    ["B", "b"],
  ], options)
end

def test_reference_value_in_array_after_bracket
  options = complete(TestMM, %Q(\
TestNode others: [|
), lambda { |r| [
    RText::DefaultCompleter::CompletionOption.from_text_extra("A", "a"),
    RText::DefaultCompleter::CompletionOption.from_text_extra("B", "b") ] })
  assert_options([
    ["A", "a"],
    ["B", "b"],
  ], options)
end

def test_reference_value_in_array_second_value
  options = complete(TestMM, %Q(\
TestNode others: [xxx, |
), lambda { |r| [
    RText::DefaultCompleter::CompletionOption.from_text_extra("A", "a"),
    RText::DefaultCompleter::CompletionOption.from_text_extra("B", "b") ] })
  assert_options([
    ["A", "a"],
    ["B", "b"],
  ], options)
end

def test_reference_value_nested
  options = complete(TestMM, %Q(\
TestNode {
  TestNode SimpleState, others: [|/StatemachineMM/State]
), lambda { |r| [
    RText::DefaultCompleter::CompletionOption.from_text_extra("A", "a"),
    RText::DefaultCompleter::CompletionOption.from_text_extra("B", "b") ] })
  assert_options([
    ["A", "a"],
    ["B", "b"],
  ], options)
end

def test_after_curly 
  options = complete TestMM, <<-END
TestNode {|
  END
  assert_options([
  ], options)
end

def test_children
  options = complete TestMM, <<-END
TestNode { 
  |
  END
  assert_options([
    ["TestNode", "<unlabled1>, <unlabled2>"],
    ["child2RoleA:", "<TestNode2>"],
    ["child2RoleB:", "<TestNode2>"],
    ["testNode3:", "<TestNode3>"]
  ], options)
end

def test_children_with_role
  options = complete TestMM, <<-END
TestNode { 
  child2RoleA:
    |
  END
  assert_options([
    ["TestNode2", "<unlabled>"],
  ], options)
end

def test_after_child_role
  options = complete TestMM, <<-END
TestNode { 
  child2RoleA:|
  END
  assert_options([
  ], options)
end

def test_after_child_role2
  options = complete TestMM, <<-END
TestNode { 
  child2RoleA: |
  END
  assert_options([
  ], options)
end

def test_after_child_role3
  options = complete TestMM, <<-END
TestNode { 
  child2RoleA: [|
  END
  assert_options([
  ], options)
end

def test_after_child_role4
  options = complete TestMM, <<-END
TestNode { 
  child2RoleA: [ |
  END
  assert_options([
  ], options)
end

def test_children_with_role_array
  options = complete TestMM, <<-END
TestNode { 
  child2RoleB: [
    |
  END
  assert_options([
    ["TestNode2", "<unlabled>"],
  ], options)
end

def test_children_prefix
  options = complete TestMM, <<-END
TestNode { 
  child2RoleB: [
    X|
  END
  assert_options([
    ["TestNode2", "<unlabled>"],
  ], options)
end

def test_children_inside_childrole
  options = complete TestMM, <<-END
TestNode { 
  child2RoleA:
    TestNode2 | 
  END
  assert_options([
    ["unlabled", "[unlabled] <EString>"],
    ["text:", "<EString>"]
  ], options)
end

def test_children_inside_childrole_array
  options = complete TestMM, <<-END
TestNode { 
  child2RoleB: [
    TestNode2 | 
  END
  assert_options([
    ["unlabled", "[unlabled] <EString>"],
    ["text:", "<EString>"]
  ], options)
end

def test_unquoted_argument
  options = complete TestMM, <<-END
TestNode { 
  child2RoleB: [
    TestNode2 text: | 
  END
  assert_options([
    ["text", "<EString>"]
  ], options)
end

def test_root
  options = complete TestMM, <<-END
|
  END
  assert_options([
    ["TestNode", "<unlabled1>, <unlabled2>"],
    ["TestNode2", "<unlabled>"],
    ["TestNode3", ""],
    ["TextNode", ""]
  ], options)
end

def test_root_no_context_lines
  options = complete TestMM, ""
  assert_options([
    ["TestNode", "<unlabled1>, <unlabled2>"],
    ["TestNode2", "<unlabled>"],
    ["TestNode3", ""],
    ["TextNode", ""]
  ], options)
end

def test_root_prefix
  options = complete TestMM, <<-END
Text|
END
  assert_options([
    ["TestNode", "<unlabled1>, <unlabled2>"],
    ["TestNode2", "<unlabled>"],
    ["TestNode3", ""],
    ["TextNode", ""]
  ], options)
end

def test_within_command
  options = complete TestMM, <<-END
Text|Node
END
  assert_options([
    ["TestNode", "<unlabled1>, <unlabled2>"],
    ["TestNode2", "<unlabled>"],
    ["TestNode3", ""],
    ["TextNode", ""]
  ], options)
end

def test_within_command2
  options = complete TestMM, <<-END
|TextNode
END
  assert_options([
    ["TestNode", "<unlabled1>, <unlabled2>"],
    ["TestNode2", "<unlabled>"],
    ["TestNode3", ""],
    ["TextNode", ""]
  ], options)
end

def assert_options(expected, options)
  assert_equal(expected, options.collect { |o| [o.insert, o.extra] })
end

def complete(mm, text, ref_comp_option_provider=nil)
  context_lines = text.split("\n")
  if context_lines.last
    pos_in_line = context_lines.last.index("|")
    context_lines.last.sub!("|", "")
  end
  lang = RText::Language.new(mm.ecore,
    :root_classes => mm.ecore.eAllClasses,
    :unlabled_arguments => lambda {|c| ["unlabled1", "unlabled2", "unlabled"]},
    :unquoted_arguments => lambda {|c| c.name == "TestNode2" ? ["text", "unlabled"] : []},
    :labeled_containments => lambda {|c| ["testNode3"]})
  context = RText::ContextBuilder.build_context(lang, context_lines, pos_in_line)
  completer = RText::DefaultCompleter.new(lang)
  class << completer
    attr_accessor :ref_comp_option_provider
    def reference_options(context)
      if ref_comp_option_provider
        ref_comp_option_provider.call(context.feature)
      else
        super
      end
    end
  end
  completer.ref_comp_option_provider = ref_comp_option_provider
  completer.complete(context)
end

end

