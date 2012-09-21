$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/metamodel_builder'
require 'rtext/language'
require 'rtext/context_builder'
require 'rtext/completer'

class CompleterTest < Test::Unit::TestCase

module TestMM
  extend RGen::MetamodelBuilder::ModuleExtension
  class TestNode2 < RGen::MetamodelBuilder::MMBase
    has_attr 'text', String
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
  end
  class TextNode < RGen::MetamodelBuilder::MMBase
  end
end

def test_after_command
  options = complete TestMM, <<-END
  TestNode |
  END
  assert_options([
    ["nums:", "<EInt>"],
    ["others:", "<TestNode>"],
    ["related:", "<TestNode>"],
    ["text:", "<EString>"],
    ["<unlabled1>", "<EString>"]
  ], options)
end

def test_lable_prefix
  options = complete TestMM, <<-END
  TestNode t|
  END
  assert_options([
    ["text:", "<EString>"]
  ], options)
end

def test_unlabled_prefix
  options = complete TestMM, <<-END
  TestNode u|
  END
  assert_options([
    ["<unlabled1>", "<EString>"]
  ], options)
end

def test_after_labled_value
  options = complete TestMM, <<-END
  TestNode nums: 1, |
  END
  assert_options([
    ["others:", "<TestNode>"],
    ["related:", "<TestNode>"],
    ["text:", "<EString>"]
  ], options)
end

def test_after_unlabled_value
  options = complete TestMM, <<-END
  TestNode "bla", |
  END
  assert_options([
    ["nums:", "<EInt>"],
    ["others:", "<TestNode>"],
    ["related:", "<TestNode>"],
    ["text:", "<EString>"],
    ["<unlabled2>", "<EInt>"]
  ], options)
end

def test_after_unlabled_value2
  options = complete TestMM, <<-END
  TestNode "bla", 1, |
  END
  assert_options([
    ["nums:", "<EInt>"],
    ["others:", "<TestNode>"],
    ["related:", "<TestNode>"],
    ["text:", "<EString>"]
  ], options)
end

def test_after_array
  options = complete TestMM, <<-END
  TestNode nums: [1, 2], |
  END
  assert_options([
    ["others:", "<TestNode>"],
    ["related:", "<TestNode>"],
    ["text:", "<EString>"]
  ], options)
end

def test_after_array_direct
  options = complete TestMM, <<-END
  TestNode nums: [1, 2]|
  END
  assert_options([
  ], options)
end

def test_value
  options = complete TestMM, <<-END
  TestNode nums: | 
  END
  assert_options([
    ["0", nil],
    ["1", nil],
    ["2", nil],
    ["3", nil],
    ["4", nil]
  ], options)
end

def test_array_value
  options = complete TestMM, <<-END
  TestNode nums: [|
  END
  assert_options([
    ["0", nil],
    ["1", nil],
    ["2", nil],
    ["3", nil],
    ["4", nil]
  ], options)
end

def test_array_value2
  options = complete TestMM, <<-END
  TestNode nums: [1,|
  END
  assert_options([
    ["0", nil],
    ["1", nil],
    ["2", nil],
    ["3", nil],
    ["4", nil]
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
    ["child2RoleB:", "<TestNode2>"]
  ], options)
end

def test_children_with_role
  options = complete TestMM, <<-END
  TestNode { 
    child2RoleA:
      |
  END
  assert_options([
    ["TestNode2", ""],
  ], options)
end

def test_children_with_role_array
  options = complete TestMM, <<-END
  TestNode { 
    child2RoleB: [
      |
  END
  assert_options([
    ["TestNode2", ""],
  ], options)
end

def test_children_prefix
  options = complete TestMM, <<-END
  TestNode { 
    child2RoleB: [
      X|
  END
  assert_options([
  ], options)
end

def test_children_inside_childrole
  options = complete TestMM, <<-END
  TestNode { 
    child2RoleA:
      TestNode2 | 
  END
  assert_options([
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
    ["text:", "<EString>"]
  ], options)
end

def test_root
  options = complete TestMM, <<-END
  |
  END
  assert_options([
    ["TestNode", "<unlabled1>, <unlabled2>"],
    ["TestNode2", ""],
    ["TextNode", ""]
  ], options)
end

def test_root_prefix
  options = complete TestMM, <<-END
  Text|
  END
  assert_options([
    ["TextNode", ""]
  ], options)
end

def assert_options(expected, options)
  assert_equal(expected, options.collect { |o| [o.text, o.extra] })
end

def complete(mm, text)
  context_lines = text.split("\n")
  pos_in_line = context_lines.last.index("|")
  context_lines.last.sub!("|", "")
  lang = RText::Language.new(mm.ecore,
    :root_classes => mm.ecore.eAllClasses,
    :unlabled_arguments => lambda {|c| ["unlabled1", "unlabled2"]})
  context = RText::ContextBuilder.build_context_element(lang, context_lines, pos_in_line)
  RText::Completer.new(lang).complete(context)
end

end

