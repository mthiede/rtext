$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/metamodel_builder'
require 'rtext/language'
require 'rtext/link_detector'

class LinkDetectorTest < Test::Unit::TestCase

module TestMM
  extend RGen::MetamodelBuilder::ModuleExtension
  class TestNode2 < RGen::MetamodelBuilder::MMBase
    has_attr 'name', String
  end
  class TestNode < RGen::MetamodelBuilder::MMBase
    has_attr 'name', String
    has_attr 'id', Integer
    has_one 'related', TestNode
    has_many 'others', TestNode
    contains_many 'children', TestNode2, 'parent'
  end
end

def test_before_command
  ld = build_link_desc TestMM, <<-END
|TestNode SomeNode, id: 1234, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  assert_link_desc ld, :element => "TestNode", :feature => nil, :backward => true, :value => "TestNode", :scol => 1, :ecol => 8
end

def test_in_command
  ld = build_link_desc TestMM, <<-END
Test|Node SomeNode, id: 1234, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  assert_link_desc ld, :element => "TestNode", :feature => nil, :backward => true, :value => "TestNode", :scol => 1, :ecol => 8
end

def test_end_of_command
  ld = build_link_desc TestMM, <<-END
TestNod|e SomeNode, id: 1234, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  assert_link_desc ld, :element => "TestNode", :feature => nil, :backward => true, :value => "TestNode", :scol => 1, :ecol => 8
end

def test_after_command
  ld = build_link_desc TestMM, <<-END
TestNode| SomeNode, id: 1234, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  assert_nil ld
end

def test_in_name
  ld = build_link_desc TestMM, <<-END
TestNode So|meNode, id: 1234, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  assert_link_desc ld, :element => "TestNode", :feature => "name", :index => 0, :backward => false, :value => "SomeNode", :scol => 10, :ecol => 17
end

def test_in_name_with_quotes
  ld = build_link_desc TestMM, <<-END
TestNode "So|meNode", id: 1234, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  assert_link_desc ld, :element => "TestNode", :feature => "name", :index => 0, :backward => false, :value => "SomeNode", :scol => 10, :ecol => 19
end

def test_after_comma
  ld = build_link_desc TestMM, <<-END
TestNode SomeNode,| id: 1234, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  assert_nil ld
end

def test_after_label
  ld = build_link_desc TestMM, <<-END
TestNode SomeNode, id:| 1234, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  assert_nil ld
end

def test_beginning_of_labled_argument
  ld = build_link_desc TestMM, <<-END
TestNode SomeNode, id: |1234, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  assert_link_desc ld, :element => "TestNode", :feature => "id", :index => 0, :backward => false, :value => 1234, :scol => 24, :ecol => 27
end

def test_in_labled_argument
  ld = build_link_desc TestMM, <<-END
TestNode SomeNode, id: 123|4, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  assert_link_desc ld, :element => "TestNode", :feature => "id", :index => 0, :backward => false, :value => 1234, :scol => 24, :ecol => 27
end

def test_after_labled_argument
  ld = build_link_desc TestMM, <<-END
TestNode SomeNode, id: 1234|, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  assert_nil ld
end

def test_in_label
  ld = build_link_desc TestMM, <<-END
TestNode SomeNode, id: 1234, re|lated: /Other/Node, others: [/NodeA, /Node/B] 
  END
  assert_nil ld
end

def test_in_reference
  ld = build_link_desc TestMM, <<-END
TestNode SomeNode, id: 1234, related: /O|ther/Node, others: [/NodeA, /Node/B] 
  END
  assert_link_desc ld, :element => "TestNode", :feature => "related", :index => 0, :backward => false, :value => "/Other/Node", :scol => 39, :ecol => 49
end

def test_before_array
  ld = build_link_desc TestMM, <<-END
TestNode SomeNode, id: 1234, related: /Other/Node, others: |[/NodeA, /Node/B] 
  END
  assert_nil ld
end

def test_ref_in_array
  ld = build_link_desc TestMM, <<-END
TestNode SomeNode, id: 1234, related: /Other/Node, others: [|/NodeA, /Node/B] 
  END
  assert_link_desc ld, :element => "TestNode", :feature => "others", :index => 0, :backward => false, :value => "/NodeA", :scol => 61, :ecol => 66 
end

def test_second_ref_in_array
  ld = build_link_desc TestMM, <<-END
TestNode SomeNode, id: 1234, related: /Other/Node, others: [/NodeA, /Node/|B] 
  END
  assert_link_desc ld, :element => "TestNode", :feature => "others", :index => 1, :backward => false, :value => "/Node/B", :scol => 69, :ecol => 75 
end

def test_backward_ref_name_in_command
  ld = build_link_desc(TestMM, {:backward_ref => "name"}, <<-END
|TestNode SomeNode, id: 1234, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  )
  assert_link_desc ld, :element => "TestNode", :feature => nil, :backward => false, :value => "TestNode", :scol => 1, :ecol => 8
end

def test_backward_ref_name_in_name
  ld = build_link_desc(TestMM, {:backward_ref => "name"}, <<-END
TestNode Som|eNode, id: 1234, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  )
  assert_link_desc ld, :element => "TestNode", :feature => "name", :index => 0, :backward => true, :value => "SomeNode", :scol => 10, :ecol => 17
end

def test_backward_ref_name_with_quotes
  ld = build_link_desc(TestMM, {:backward_ref => "name"}, <<-END
TestNode "Som|eNode", id: 1234, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  )
  assert_link_desc ld, :element => "TestNode", :feature => "name", :index => 0, :backward => true, :value => "SomeNode", :scol => 10, :ecol => 19
end

def test_backward_ref_id_in_id
  ld = build_link_desc(TestMM, {:backward_ref => "id"}, <<-END
TestNode SomeNode, id: |1234, related: /Other/Node, others: [/NodeA, /Node/B] 
  END
  )
  assert_link_desc ld, :element => "TestNode", :feature => "id", :index => 0, :backward => true, :value => 1234, :scol => 24, :ecol => 27
end

def test_command_only
  ld = build_link_desc(TestMM, <<-END
Tes|tNode
  END
  )
  assert_link_desc ld, :element => "TestNode", :feature => nil, :backward => true, :value => "TestNode", :scol => 1, :ecol => 8 
end

def test_command_and_name_only
  ld = build_link_desc(TestMM, <<-END
TestNode |SomeNode
  END
  )
  assert_link_desc ld, :element => "TestNode", :feature => "name", :index => 0, :backward => false, :value => "SomeNode", :scol => 10, :ecol => 17
end

def test_command_and_name_only_backward_ref_name
  ld = build_link_desc(TestMM, {:backward_ref => "name"}, <<-END
TestNode |SomeNode
  END
  )
  assert_link_desc ld, :element => "TestNode", :feature => "name", :index => 0, :backward => true, :value => "SomeNode", :scol => 10, :ecol => 17
end

def test_command_and_name_curly_no_ws
  ld = build_link_desc(TestMM, {:backward_ref => "name"}, <<-END
TestNode Some|Node{
  END
  )
  assert_link_desc ld, :element => "TestNode", :element_name => "SomeNode", :feature => "name", :index => 0, :backward => true, :value => "SomeNode", :scol => 10, :ecol => 17
end

def test_child_within_command
  ld = build_link_desc(TestMM, {:backward_ref => "name"}, <<-END
TestNode SomeNode {
  Test|Node2 SomeOtherNode
  END
  )
  assert_link_desc ld, :element => "TestNode2", :feature => nil, :backward => false, :value => "TestNode2", :scol => 3, :ecol => 11
end

def test_child_with_label_after_command
  ld = build_link_desc(TestMM, {:backward_ref => "name"}, <<-END
TestNode SomeNode {
  children:
    TestNode2 |SomeOtherNode
  END
  )
  assert_link_desc ld, :element => "TestNode2", :feature => "name", :index => 0, :backward => true, :value => "SomeOtherNode", :scol => 15, :ecol => 27
end

def test_child_with_label_within_command
  ld = build_link_desc(TestMM, {:backward_ref => "name"}, <<-END
TestNode SomeNode {
  children:
    Test|Node2 SomeOtherNode
  END
  )
  assert_link_desc ld, :element => "TestNode2", :feature => nil, :backward => false, :value => "TestNode2", :scol => 5, :ecol => 13
end

def test_child_with_label_within_command_square_brackets
  ld = build_link_desc(TestMM, {:backward_ref => "name"}, <<-END
TestNode SomeNode {
  children: [
    Test|Node2 SomeOtherNode
  END
  )
  assert_link_desc ld, :element => "TestNode2", :feature => nil, :backward => false, :value => "TestNode2", :scol => 5, :ecol => 13
end

def build_link_desc(mm, text, text2=nil)
  if text.is_a?(Hash)
    options = text
    context_lines = text2.split("\n")
  else
    options = {}
    context_lines = text.split("\n")
  end
  pos_in_line = context_lines.last.index("|")+1
  context_lines.last.sub!("|", "")
  lang = RText::Language.new(mm.ecore,
    :unlabled_arguments => proc {|c| ["name"]},
    :backward_ref_attribute => proc {|c|
      if options[:backward_ref]
        options[:backward_ref]
      else
        nil
      end
    })
  RText::LinkDetector.new(lang).detect(context_lines, pos_in_line)
end

def assert_link_desc(ld, options)
  if options[:element]
    assert_equal options[:element], ld.element.class.ecore.name
  else
    assert_nil ld.element
  end
  if options[:element_name]
    assert_equal options[:element_name], ld.element.name
  end
  if options[:feature]
    assert_equal options[:feature], ld.feature.name
  else
    assert_nil ld.feature
  end
  if options[:index]
    assert_equal options[:index], ld.index
  else
    assert_nil ld.index
  end
  assert_equal options[:backward], ld.backward
  assert_equal options[:value], ld.value
  assert_equal options[:scol], ld.scol
  assert_equal options[:ecol], ld.ecol
end

end

