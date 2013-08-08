# coding: binary
$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'bigdecimal'
require 'rgen/environment'
require 'rgen/metamodel_builder'
require 'rtext/instantiator'
require 'rtext/language'

class InstantiatorTest < Test::Unit::TestCase

  module TestMM
    extend RGen::MetamodelBuilder::ModuleExtension
    class TestNode < RGen::MetamodelBuilder::MMBase
      SomeEnum = RGen::MetamodelBuilder::DataTypes::Enum.new([:A, :B, :'non-word*chars', :'2you'])
      has_attr 'text', String
      has_attr 'integer', Integer
      has_attr 'boolean', Boolean
      has_attr 'enum', SomeEnum
      has_many_attr 'nums', Integer
      has_attr 'float', Float
      has_one 'related', TestNode
      has_many 'others', TestNode
      contains_many 'childs', TestNode, 'parent'
    end
    class SubNode < TestNode
    end
  end

  module TestMM2
    extend RGen::MetamodelBuilder::ModuleExtension
    class TestNode < RGen::MetamodelBuilder::MMBase
      contains_one 'singleChild', TestNode, 'parent'
    end
    class TestNode2 < RGen::MetamodelBuilder::MMBase
    end
    class TestNode3 < RGen::MetamodelBuilder::MMBase
    end
    class TestNode4 < TestNode
    end
    TestNode.contains_one 'singleChild2a', TestNode2, 'parentA'
    TestNode.contains_one 'singleChild2b', TestNode2, 'parentB'
  end

  module TestMMLinenoFilenameFragment
    extend RGen::MetamodelBuilder::ModuleExtension
    class TestNode < RGen::MetamodelBuilder::MMBase
      has_attr 'text', String
      has_attr 'lineno', Integer
      has_attr 'filename', String
      has_attr 'fragmentr', String
      contains_many 'childs', TestNode, 'parent'
    end
  end

  module TestMMAbstract
    extend RGen::MetamodelBuilder::ModuleExtension
    class TestNode < RGen::MetamodelBuilder::MMBase
      abstract
    end
  end

  module TestMMData
    extend RGen::MetamodelBuilder::ModuleExtension
    # class "Data" exists in the standard Ruby namespace
    class Data < RGen::MetamodelBuilder::MMBase
      has_attr 'notTheBuiltin', String
    end
  end

  module TestMMSubpackage
    extend RGen::MetamodelBuilder::ModuleExtension
    module SubPackage
      extend RGen::MetamodelBuilder::ModuleExtension
      class TestNodeSub < RGen::MetamodelBuilder::MMBase
        has_attr 'text', String
      end
      class Data < RGen::MetamodelBuilder::MMBase
        has_attr 'notTheBuiltin', String
      end
    end
  end

  module TestMMNonRootClass
    extend RGen::MetamodelBuilder::ModuleExtension
    class NonRootClass < RGen::MetamodelBuilder::MMBase
    end
  end

  module TestMMContextSensitiveCommands
    extend RGen::MetamodelBuilder::ModuleExtension
    module SubPackage2
      extend RGen::MetamodelBuilder::ModuleExtension
      class Command < RGen::MetamodelBuilder::MMBase
      end
    end
    module SubPackage1
      extend RGen::MetamodelBuilder::ModuleExtension
      class Command < RGen::MetamodelBuilder::MMBase
        contains_one 'command', SubPackage2::Command, 'super'
      end
    end
    class TestNode < RGen::MetamodelBuilder::MMBase
      contains_one 'command', SubPackage1::Command, 'testNode'
    end
  end

  def test_simple
    env, problems = instantiate(%Q(
      TestNode text: "some text", nums: [1,2] {
        TestNode text: "child"
        TestNode text: "child2"
      }
      ), TestMM)
    assert_no_problems(problems)
    assert_model_simple(env, :with_nums)
  end

  def test_multiple_roots
    env, problems = instantiate(%Q(
      TestNode
      TestNode
    ), TestMM)
    assert_no_problems(problems)
    assert_equal 2, env.elements.size
  end

  def test_comment
    env, problems = instantiate(%Q(
      # comment 1
      TestNode text: "some text" {# comment 1.1
        childs: [ # comment 1.2
          # comment 2
          TestNode text: "child" # comment 2.1
          # comment 3
          TestNode text: "child2" #comment 3.1
          # unassociated
        ] # comment 1.3
        # unassociated
      } # comment 1.4
      #comment 1
      TestNode { #comment 1.1
        childs: # comment 1.2
          TestNode text: "child" #comment2
        # unassociated
      }# comment 1.3
      # unassociated
      ), TestMM)
    assert_no_problems(problems)
    assert_model_simple(env)
  end

  def test_comment_only
    env, problems = instantiate(%Q(
      # comment 1
      ), TestMM)
    assert_no_problems(problems)
  end

  def test_empty
    env, problems = instantiate("", TestMM)
    assert_no_problems(problems)
  end

  # 
  # options
  # 

  def test_line_number_setter
    env, problems = instantiate(%q(
      TestNode text: "node1" {
        TestNode text: "node2"

        #some comment
        TestNode text: "node3"
      }
      TestNode text: "node4"
    ), TestMMLinenoFilenameFragment, :line_number_attribute => "lineno")
    assert_no_problems(problems)
    assert_equal 2, env.find(:text => "node1").first.lineno
    assert_equal 3, env.find(:text => "node2").first.lineno
    assert_equal 6, env.find(:text => "node3").first.lineno
    assert_equal 8, env.find(:text => "node4").first.lineno
  end

  def test_missing_line_number_setter
    env, problems = instantiate(%Q(
      TestNode text: A
    ), TestMMLinenoFilenameFragment, :line_number_attribute => "wrong_attribute_name")
    assert_no_problems(problems)
    assert_nil env.elements.first.lineno
  end

  def test_root_elements
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode text: A
      TestNode text: B
      TestNode text: C
    ), TestMM, :root_elements => root_elements)
    assert_no_problems(problems)
    assert_equal ["A", "B", "C"], root_elements.text
  end

  def test_file_name_option
    env, problems = instantiate(%Q(
      TestNode text: A
      TestNode text: B
      TestNode a problem here 
    ), TestMM, :file_name => "some_file")
    assert_equal "some_file", problems.first.file
  end

  def test_file_name_setter
    env, problems = instantiate(%Q(
      TestNode text: A
    ), TestMMLinenoFilenameFragment, :file_name => "some_file", :file_name_attribute => "filename")
    assert_equal "some_file", env.elements.first.filename 
  end

  def test_missing_file_name_setter
    env, problems = instantiate(%Q(
      TestNode text: A
    ), TestMMLinenoFilenameFragment, :file_name => "some_file", :file_name_attribute => "wrong_attribute_name")
    assert_nil env.elements.first.filename 
  end

  def test_fragment_ref_setter
    the_ref = "is a string here but would normally be an RGen fragment"
    env, problems = instantiate(%Q(
      TestNode text: A
    ), TestMMLinenoFilenameFragment, :fragment_ref => the_ref, :fragment_ref_attribute => "fragmentr")
    assert_equal the_ref.object_id, env.elements.first.fragmentr.object_id
  end

  def test_missing_fragment_ref_setter
    the_ref = "is a string here but would normally be an RGen fragment"
    env, problems = instantiate(%Q(
      TestNode text: A
    ), TestMMLinenoFilenameFragment, :fragment_ref => the_ref, :fragment_ref_attribute => "wrong_attribute_name")
    assert_nil env.elements.first.fragmentr
  end

  #
  # children with role
  #

  def test_child_role
    env, problems = instantiate(%Q(
      TestNode text: "some text" {
        TestNode text: "child"
        childs:
          TestNode text: "child2"
      }
      ), TestMM)
    assert_no_problems(problems)
    assert_model_simple(env)
  end

  def test_child_role2
    env, problems = instantiate(%Q(
      TestNode text: "some text" {
        childs: [
          TestNode text: "child"
          TestNode text: "child2"
        ]
      }
      ), TestMM)
    assert_no_problems(problems)
    assert_model_simple(env)
  end

  def test_child_role3
    env, problems = instantiate(%Q(
      TestNode text: "some text" {
        childs:
          TestNode text: "child"
        childs:
          TestNode text: "child2"
      }
      ), TestMM)
    assert_no_problems(problems)
    assert_model_simple(env)
  end

  def test_child_role4
    env, problems = instantiate(%Q(
      TestNode text: "some text" {
        childs: [
          TestNode text: "child"
        ]
        childs: [
          TestNode text: "child2"
        ]
      }
      ), TestMM)
    assert_no_problems(problems)
    assert_model_simple(env)
  end

  def test_child_role_empty
    env, problems = instantiate(%Q(
      TestNode {
        childs: [
        ]
      }
    ), TestMM)
    assert_no_problems(problems)
  end


  #
  # whitespace
  # 

  def test_whitespace1
    env, problems = instantiate(%Q(
      TestNode    text:  "some text" , nums: [ 1 , 2 ] {

        # comment

        TestNode text: "child"

        TestNode text: "child2"

      }
      ), TestMM)
    assert_no_problems(problems)
    assert_model_simple(env, :with_nums)
  end

  def test_whitespace2
    env, problems = instantiate(%Q(
      # comment1

      # comment2

      TestNode    text:  "some text"  {

        childs:

        # comment

        TestNode text: "child"

        childs:  [

        TestNode text: "child2"

        ]

      }
      ), TestMM)
    assert_no_problems(problems)
    assert_model_simple(env)
  end

  def test_no_newline_at_eof
    env, problems = instantiate(%Q(
      TestNode), TestMM)
    assert_no_problems(problems)
  end

  def test_no_newline_at_eof2
    env, problems = instantiate(%Q(
      TestNode {
      }), TestMM)
    assert_no_problems(problems)
  end

  #
  # references
  # 

  def test_references
    unresolved_refs = []
    env, problems = instantiate(%Q(
      TestNode text: "root" {
        TestNode related: /
        TestNode related: //
        TestNode related: /some
        TestNode related: //some
        TestNode related: /some/
        TestNode related: some/
        TestNode related: some//
        TestNode related: some
        TestNode related: /some/reference
        TestNode related: /some/reference/
        TestNode related: some/reference/
        TestNode related: some/reference
      }
    ), TestMM, :unresolved_refs => unresolved_refs)
    assert_no_problems(problems)
    ref_targets = [ 
      "/",
      "//",
      "/some",
      "//some",
      "/some/",
      "some/",
      "some//",
      "some",
      "/some/reference",
      "/some/reference/",
      "some/reference/",
      "some/reference"
    ]
    assert_equal ref_targets, env.find(:text => "root").first.childs.collect{|c| c.related.targetIdentifier}
    assert_equal ref_targets, unresolved_refs.collect{|ur| ur.proxy.targetIdentifier}
    assert unresolved_refs.all?{|ur| ur.feature_name == "related"}
  end

  def test_references_many
    env, problems = instantiate(%Q(
      TestNode text: "root" {
        TestNode others: /other
        TestNode others: [ /other ]
        TestNode others: [ /other1, /other2 ]
      }
    ), TestMM)
    assert_no_problems(problems)
    assert_equal [ 
      [ "/other" ],
      [ "/other" ],
      [ "/other1", "/other2" ],
    ], env.find(:text => "root").first.childs.collect{|c| c.others.collect{|p| p.targetIdentifier}}
  end

  def test_reference_regexp
    env, problems = instantiate(%Q(
      TestNode text: "root" {
        TestNode related: some
        TestNode related: ::some
        TestNode related: some::reference
        TestNode related: ::some::reference
      }
    ), TestMM, :reference_regexp => /\A\w*(::\w*)+/)
    assert_no_problems(problems)
    assert_equal [ 
      "some",
      "::some",
      "some::reference",
      "::some::reference"
     ], env.find(:text => "root").first.childs.collect{|c| c.related.targetIdentifier}
  end

  #
  # unlabled arguments
  # 

  def test_unlabled_arguments
    env, problems = instantiate(%Q(
      TestNode "some text", [1,2] {
        TestNode "child"
        TestNode "child2"
      }
      ), TestMM, :unlabled_arguments => proc {|clazz| ["text", "nums"]})
    assert_no_problems(problems)
    assert_model_simple(env, :with_nums)
  end

  def test_unlabled_arguments_not_in_front
    env, problems = instantiate(%Q(
      TestNode nums: [1,2], "some text" {
        TestNode "child"
        TestNode "child2"
      }
      ), TestMM, :unlabled_arguments => proc {|clazz| ["text", "nums"]})
    assert_no_problems(problems)
    assert_model_simple(env, :with_nums)
  end

  def test_unlabled_arguments_using_labled
    env, problems = instantiate(%Q(
      TestNode text: "some text", nums: [1,2] {
        TestNode text: "child"
        TestNode text: "child2"
      }
      ), TestMM, :unlabled_arguments => proc {|clazz| ["text", "nums"]})
    assert_no_problems(problems)
    assert_model_simple(env, :with_nums)
  end

  def test_unlabled_arguments_subclass
    env, problems = instantiate(%Q(
      SubNode "some text", [1, 2] {
        TestNode text: "child"
        TestNode text: "child2"
      }
      ), TestMM, :unlabled_arguments => proc {|clazz| ["text", "nums"]})
    assert_no_problems(problems)
    assert_model_simple(env, :with_nums)
  end
  
  # 
  # context sensitive commands
  #

  def test_context_sensitive
    env, problems = instantiate(%Q(
      TestNode {
        Command {
          Command
        }
      }
      ), TestMMContextSensitiveCommands)
    assert_no_problems(problems)
    root = env.find(:class => TestMMContextSensitiveCommands::TestNode).first
    assert_not_nil(root)
    assert(root.command.is_a?(TestMMContextSensitiveCommands::SubPackage1::Command))
    assert(root.command.command.is_a?(TestMMContextSensitiveCommands::SubPackage2::Command))
  end

  def test_context_sensitive_command_name_mapping
    env, problems = instantiate(%Q(
      Command {
        Command {
          Command
        }
      }
      ), TestMMContextSensitiveCommands, :command_name_provider => lambda do |c|
        "Command" end)
    assert_no_problems(problems)
    root = env.find(:class => TestMMContextSensitiveCommands::TestNode).first
    assert_not_nil(root)
    assert(root.command.is_a?(TestMMContextSensitiveCommands::SubPackage1::Command))
    assert(root.command.command.is_a?(TestMMContextSensitiveCommands::SubPackage2::Command))
  end

  #
  # problems
  # 

  def test_unexpected_end_of_file
    env, problems = instantiate(%Q(
      TestNode text: "some text" {
    ), TestMM)
    assert_problems([[/unexpected end of file, expected \}/i, 2]], problems)
  end

  def test_unknown_command
    env, problems = instantiate(%Q(
      NotDefined 
    ), TestMM)
    assert_problems([[/unknown command 'NotDefined'/i, 2]], problems)
  end

  def test_unknown_command_abstract
    env, problems = instantiate(%Q(
      TestNode
    ), TestMMAbstract)
    assert_problems([[/unknown command 'TestNode'/i, 2]], problems)
  end

  def test_unexpected_unlabled_argument
    env, problems = instantiate(%Q(
      TestNode "more text"
    ), TestMM)
    assert_problems([[/unexpected unlabled argument, 0 unlabled arguments expected/i, 2]], problems)
  end

  def test_unknown_child_role
    env, problems = instantiate(%Q(
      TestNode {
        notdefined:
          TestNode
      }
    ), TestMM)
    assert_problems([[/unknown child role 'notdefined'/i, 3]], problems)
  end

  def test_not_a_child_role
    env, problems = instantiate(%Q(
      TestNode {
        text:
          TestNode
        others:
          TestNode
      }
    ), TestMM)
    assert_problems([
      [/role 'text' can not take child elements/i, 3],
      [/role 'others' can not take child elements/i, 5]
    ], problems)
  end

  def test_not_a_single_child
    env, problems = instantiate(%Q(
      TestNode {
        singleChild: [
          TestNode
          TestNode
        ]
      }
    ), TestMM2)
    assert_problems([
      [/only one child allowed in role 'singleChild'/i, 5]
    ], problems)
  end

  def test_not_a_single_child2
    env, problems = instantiate(%Q(
      TestNode {
        singleChild:
          TestNode
        singleChild:
          TestNode
      }
    ), TestMM2)
    assert_problems([
      [/only one child allowed in role 'singleChild'/i, 6]
    ], problems)
  end

  def test_wrong_child_role
    env, problems = instantiate(%Q(
      TestNode {
        singleChild:
          TestNode2
      }
    ), TestMM2)
    assert_problems([
      [/role 'singleChild' can not take a TestNode2, expected TestNode/i, 4]
    ], problems)
  end

  def test_child_role_without_child
    env, problems = instantiate(%Q(
      TestNode {
        singleChild:
      }
    ), TestMM2)
    assert_problems([
      [/unexpected \}, expected identifier/i, 4]
    ], problems)
  end

  def test_wrong_child
    env, problems = instantiate(%Q(
      TestNode {
        TestNode3
      }
    ), TestMM2)
    assert_problems([
      [/command 'TestNode3' can not be used in this context/i, 3]
    ], problems)
  end

  def test_ambiguous_child_role
    env, problems = instantiate(%Q(
      TestNode {
        TestNode2
      }
    ), TestMM2)
    assert_problems([
      [/role of element is ambiguous, use a role label/i, 3]
    ], problems)
  end

  def test_non_ambiguous_child_role_subclass
    env, problems = instantiate(%Q(
      TestNode {
        TestNode4
      }
    ), TestMM2)
    assert_no_problems(problems)
  end

  def test_not_a_single_child3
    env, problems = instantiate(%Q(
      TestNode {
        TestNode
        TestNode
      }
    ), TestMM2)
    assert_problems([
      [/only one child allowed in role 'singleChild'/i, 4]
    ], problems)
  end

  def test_unknown_argument
    env, problems = instantiate(%Q(
      TestNode unknown: "some text"
    ), TestMM)
    assert_problems([[/unknown argument 'unknown'/i, 2]], problems)
  end

  def test_attribute_in_child_reference
    env, problems = instantiate(%Q(
      TestNode singleChild: "some text"
    ), TestMM2)
    assert_problems([[/argument 'singleChild' can only take child elements/i, 2]], problems)
  end

  def test_arguments_duplicate
    env, problems = instantiate(%Q(
      TestNode text: "some text", text: "more text"
    ), TestMM)
    assert_problems([[/argument 'text' already defined/i, 2]], problems)
  end

  def test_unlabled_arguments_duplicate
    env, problems = instantiate(%Q(
      TestNode text: "some text", "more text"
    ), TestMM, :unlabled_arguments => proc {|c| ["text"]})
    assert_problems([[/argument 'text' already defined/i, 2]], problems)
  end

  def test_multiple_arguments_in_non_many_attribute
    env, problems = instantiate(%Q(
      TestNode text: ["text1", "text2"]
    ), TestMM)
    assert_problems([[/argument 'text' can take only one value/i, 2]], problems)
  end

  def test_wrong_argument_type
    env, problems = instantiate(%Q(
      TestNode text: 1 
      TestNode integer: "text" 
      TestNode integer: true 
      TestNode integer: 1.2 
      TestNode integer: a 
      TestNode integer: /a 
      TestNode enum: 1 
      TestNode enum: x 
      TestNode related: 1
    ), TestMM)
    assert_problems([
      [/argument 'text' can not take a integer, expected string/i, 2],
      [/argument 'integer' can not take a string, expected integer/i, 3],
      [/argument 'integer' can not take a boolean, expected integer/i, 4],
      [/argument 'integer' can not take a float, expected integer/i, 5],
      [/argument 'integer' can not take a identifier, expected integer/i, 6],
      [/argument 'integer' can not take a reference, expected integer/i, 7],
      [/argument 'enum' can not take a integer, expected identifier/i, 8],
      [/argument 'enum' can not take value x, expected A, B/i, 9],
      [/argument 'related' can not take a integer, expected reference, identifier/i, 10]
    ], problems)
  end

  def test_missing_opening_brace
    env, problems = instantiate(%Q(
      TestNode 
      }
    ), TestMM)
    assert_problems([[/unexpected \}, expected identifier/i, 3]], problems)
  end

  def test_invalid_root
    env, problems = instantiate(%Q(
      NonRootClass
    ), TestMMNonRootClass)
    assert_problems([[/command 'NonRootClass' can not be used on root level/i, 2]], problems)
  end

  #
  # problem recovery
  #

  def test_missing_value
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode nums: 1, text:
      TestNode nums: 2, text: {
        SubNode
      }
      TestNode text: ,nums: 3 {
        SubNode
      }
      TestNode nums: , text: , bla: 
    ), TestMM, :root_elements => root_elements)
    assert_equal 4, root_elements.size
    assert_equal [1], root_elements[0].nums
    assert_nil root_elements[0].text
    assert_equal [2], root_elements[1].nums
    assert_equal 1, root_elements[1].childs.size
    assert_equal [3], root_elements[2].nums
    assert_equal 1, root_elements[2].childs.size
    assert_problems([
      [/unexpected newline, expected.*integer/i, 2],
      [/unexpected \{, expected.*integer/i, 3],
      [/unexpected ,, expected.*integer/i, 6],
      [/unexpected ,, expected.*integer/i, 9],
      [/unexpected ,, expected.*integer/i, 9],
      [/unexpected newline, expected.*integer/i, 9],
      [/unknown argument 'bla'/i, 9],
    ], problems)
  end

  def test_missing_comma
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode nums: 1 text: "bla"
    ), TestMM, :root_elements => root_elements)
    assert_equal 1, root_elements.size
    assert_equal [1], root_elements[0].nums
    assert_equal "bla", root_elements[0].text
    assert_problems([
      [/unexpected label .*, expected ,/i, 2],
    ], problems)
  end

  def test_missing_label
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode nums: 1 "bla"
    ), TestMM, :root_elements => root_elements)
    assert_equal 1, root_elements.size
    assert_equal [1], root_elements[0].nums
    assert_problems([
      [/unexpected string 'bla', expected ,/i, 2],
      [/unexpected unlabled argument/i, 2]
    ], problems)
  end

  def test_unclosed_bracket
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode nums: [1, "bla"
      TestNode nums: [1, text: "bla"
      TestNode nums: [1 text: "bla"
      TestNode nums: [1 "bla"
      TestNode [1, "bla"
      TestNode [1, "bla" [
      TestNode [1, "bla", [
    ), TestMM, :root_elements => root_elements)
    assert_equal 7, root_elements.size
    assert_equal [1], root_elements[0].nums
    assert_nil root_elements[0].text
    assert_equal [1], root_elements[1].nums
    assert_equal "bla", root_elements[1].text
    assert_equal [1], root_elements[2].nums
    assert_equal "bla", root_elements[2].text
    assert_equal [1], root_elements[3].nums
    assert_nil root_elements[3].text
    assert_equal [], root_elements[4].nums
    assert_nil root_elements[4].text
    assert_problems([
      [/unexpected newline, expected \]/i, 2],
      [/argument 'nums' can not take a string, expected integer/i, 2],
      [/unexpected label 'text', expected identifier/i, 3],
      [/unexpected label 'text', expected \]/i, 4],
      [/unexpected string 'bla', expected ,/i, 5],
      [/argument 'nums' can not take a string, expected integer/i, 5],
      [/unexpected newline, expected \]/i, 5],
      [/unexpected newline, expected \]/i, 6],
      [/unexpected unlabled argument/i, 6],
      [/unexpected \[, expected \]/i, 7],
      [/unexpected newline, expected \]/i, 7],
      [/unexpected unlabled argument/i, 7],
      [/unexpected unlabled argument/i, 7],
      [/unexpected \[, expected identifier/i, 8],
      [/unexpected unlabled argument/i, 8],
      [/unexpected unlabled argument/i, 8],
      [/unexpected newline, expected \]/i, 8],
    ], problems)
  end

  def test_closing_bracket
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode ] 
      TestNode 1 ] 
      TestNode 1, ] 
      TestNode nums: ]1, "bla"
      TestNode text: "bla" ] 
    ), TestMM, :root_elements => root_elements)
    assert_equal 5, root_elements.size
    assert_equal [], root_elements[3].nums
    assert_equal "bla", root_elements[4].text
    assert_problems([
      [/unexpected \], expected newline/i, 2],
      [/unexpected \], expected newline/i, 3],
      [/unexpected unlabled argument/i, 3],
      [/unexpected \], expected identifier/i, 4],
      [/unexpected unlabled argument/i, 4],
      [/unexpected \], expected identifier/i, 5],
      [/unexpected \], expected newline/i, 6],
    ], problems)
  end

  def test_closing_brace
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode } 
      TestNode 1 } 
      TestNode 1, } 
      TestNode nums: }1, "bla"
      TestNode text: "bla" } 
    ), TestMM, :root_elements => root_elements)
    assert_equal 5, root_elements.size
    assert_equal [], root_elements[3].nums
    assert_equal "bla", root_elements[4].text
    assert_problems([
      [/unexpected \}, expected newline/i, 2],
      [/unexpected \}, expected newline/i, 3],
      [/unexpected unlabled argument/i, 3],
      [/unexpected \}, expected identifier/i, 4],
      [/unexpected unlabled argument/i, 4],
      [/unexpected \}, expected identifier/i, 5],
      [/unexpected \}, expected newline/i, 6],
    ], problems)
  end

  def test_starting_non_command
    root_elements = []
    env, problems = instantiate(%Q(
      \)
      TestNode
      *
      TestNode
      $
      TestNode
      ,
      TestNode
      [
      TestNode
      {
      TestNode
      ]
      TestNode
      }
      TestNode
      }}
    ), TestMM, :root_elements => root_elements)
    assert_equal 8, root_elements.size
    assert_problems([
      [/parse error on token '\)'/i, 2],
      [/parse error on token '\*'/i, 4],
      [/parse error on token '\$'/i, 6],
      [/unexpected ,, expected identifier/i, 8],
      [/unexpected \[, expected identifier/i, 10],
      [/unexpected \{, expected identifier/i, 12],
      [/unexpected \], expected identifier/i, 14],
      [/unexpected \}, expected identifier/i, 16],
      [/unexpected \}, expected identifier/i, 18],
    ], problems)
  end

  def test_parse_error_in_argument_list
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode text: "bla", * nums: 1
      TestNode text: "bla" * , nums: 1
      TestNode ?text: "bla"
      TestNode nums: [1, * 3]
    ), TestMM, :root_elements => root_elements)
    assert_equal 4, root_elements.size
    assert_equal "bla", root_elements[0].text
    assert_equal [1], root_elements[0].nums
    assert_equal "bla", root_elements[1].text
    assert_equal [1], root_elements[1].nums
    assert_equal "bla", root_elements[2].text
    assert_equal [1, 3], root_elements[3].nums
    assert_problems([
      [/parse error on token '\*'/i, 2],
      [/parse error on token '\*'/i, 3],
      [/parse error on token '\?'/i, 4],
      [/parse error on token '\*'/i, 5],
    ], problems)
  end

  def test_unclosed_brace
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode { 
    ), TestMM, :root_elements => root_elements)
    assert_equal 1, root_elements.size
    assert_problems([
      [/unexpected end of file, expected \}/i, 2]
    ], problems)
  end

  def test_unclosed_brace2
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode { 
        *
    ), TestMM, :root_elements => root_elements)
    assert_equal 1, root_elements.size
    assert_problems([
      [/parse error on token '\*'/i, 3]
    ], problems)
  end

  def test_unclosed_brace3
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode { 
        childs:
    ), TestMM, :root_elements => root_elements)
    assert_equal 1, root_elements.size
    assert_problems([
      [/unexpected end of file, expected identifier/i, 3]
    ], problems)
  end

  def test_label_without_child
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode { 
        childs:
      }
    ), TestMM, :root_elements => root_elements)
    assert_equal 1, root_elements.size
    assert_problems([
      [/unexpected \}, expected identifier/i, 4]
    ], problems)
  end

  def test_unclosed_bracket
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode { 
        childs: [
    ), TestMM, :root_elements => root_elements)
    assert_equal 1, root_elements.size
    assert_problems([
      [/unexpected end of file, expected \]/i, 3]
    ], problems)
  end

  def test_child_label_problems
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode { 
        childs: x 
          SubNode
        childs: * 
          SubNode
        childs: & 
      }
    ), TestMM, :root_elements => root_elements)
    assert_equal 1, root_elements.size
    assert_equal 2, root_elements[0].childs.size
    assert_problems([
      [/unexpected identifier 'x', expected newline/i, 3],
      [/parse error on token '\*'/i, 5],
      [/parse error on token '&'/i, 7]
    ], problems)
  end

  def test_child_label_problems_with_bracket
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode { 
        childs: [ x 
          SubNode
        ]
        childs: [ * 
          SubNode
        ]
        childs: [& 
        ]
      }
    ), TestMM, :root_elements => root_elements)
    assert_equal 1, root_elements.size
    assert_equal 2, root_elements[0].childs.size
    assert_problems([
      [/unexpected identifier 'x', expected newline/i, 3],
      [/parse error on token '\*'/i, 6],
      [/parse error on token '&'/i, 9]
    ], problems)
  end

  def test_missing_closing_bracket
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode { 
        childs: [
          SubNode
        childs: [
          SubNode
        SubNode
      }
    ), TestMM, :root_elements => root_elements)
    assert_equal 1, root_elements.size
    assert_equal 3, root_elements[0].childs.size
    assert_problems([
      [/unexpected label 'childs', expected identifier/i, 5],
      [/unexpected \}, expected identifier/i, 8],
    ], problems)
  end

  def test_missing_closing_brace
    root_elements = []
    env, problems = instantiate(%Q(
      TestNode { 
        TestNode {
          TestNode
      }
    ), TestMM, :root_elements => root_elements)
    assert_equal 1, root_elements.size
    assert_equal 1, root_elements[0].childs.size
    assert_equal 1, root_elements[0].childs[0].childs.size
    assert_problems([
      [/unexpected end of file, expected \}/i, 5],
    ], problems)
  end

  #
  # command name provider
  #

  def test_command_name_provider
    env, problems = instantiate(%Q(
      TestNodeX text: "some text", nums: [1,2] {
        TestNodeX text: "child"
        TestNodeX text: "child2"
      }
      ), TestMM, :command_name_provider => proc do |c|
        c.name + "X"
      end)
    assert_no_problems(problems)
    assert_model_simple(env, :with_nums)
  end

  def test_command_name_provider_ambiguous
    begin
      env, problems = instantiate(%Q(
        TestNode
      ), TestMM, :command_name_provider => proc do |c|
        "Fixed"
      end)
      assert false
    rescue RuntimeError => e
      assert e.message =~ /ambiguous command name/
    end
  end

  #
  # comment handler
  # 

  def test_comment_handler
    proc_calls = 0
    env, problems = instantiate(%Q(
      #comment
      TestNode text: "node1"
      #comment
      #  multiline
      TestNode text: "node2"
      TestNode text: "node3" #comment
      #above
      TestNode text: "node4" {#right1
        childs: [ #right2
          #unassociated1
        ] #right3
        #unassociated2
      } #below
      #above1
      #above2
      TestNode text: "node5" { #right1
        childs: #right2
          TestNode
      }#below
      #comment without
      #an element following
    ), TestMM, :comment_handler => proc {|c,k,e,env|
      proc_calls += 1
      if e.nil?
        case proc_calls
        when 4
          assert_equal "unassociated1", c
          assert_equal :unassociated, k
        when 5
          assert_equal "unassociated2", c
          assert_equal :unassociated, k
        when 15
          assert_equal "comment without\nan element following", c
          assert_equal :unassociated, k
        end
      elsif e.text == "node1"
        assert_equal "comment", c
        assert_equal :above, k
      elsif e.text == "node2"
        assert_equal "comment\n  multiline", c
        assert_equal :above, k
      elsif e.text == "node3"
        assert_equal "comment", c
        assert_equal :eol, k
      elsif e.text == "node4" 
        case proc_calls
        when 6
          assert_equal "above", c
          assert_equal :above, k
        when 7
          assert_equal "right1", c
          assert_equal :eol, k
        when 8
          assert_equal "right2", c
          assert_equal :eol, k
        when 9
          assert_equal "right3", c
          assert_equal :eol, k
        when 10 
          assert_equal "below", c
          assert_equal :eol, k
        end
      elsif e.text == "node5"
        case proc_calls
        when 11 
          assert_equal "above1\nabove2", c
          assert_equal :above, k
        when 12
          assert_equal "right1", c
          assert_equal :eol, k
        when 13
          assert_equal "right2", c
          assert_equal :eol, k
        when 14
          assert_equal "below", c
          assert_equal :eol, k
        end
      else
        assert false, "unexpected element in comment handler"
      end
      true
    })
    assert_no_problems(problems)
    assert_equal 15, proc_calls
  end

  def test_comment_handler_comment_not_allowed
    env, problems = instantiate(%Q(
      #comment
      TestNode
    ), TestMM, :comment_handler => proc {|c,k,e,env|
      false
    })
    assert_problems([[/element can not take this comment/, 3]], problems)
  end

  def test_comment_handler_comment_not_allowed_unassociated
    env, problems = instantiate(%Q(
      #comment
    ), TestMM, :comment_handler => proc {|c,k,e,env|
      false
    })
    assert_problems([[/Unassociated comment not allowed/, 2]], problems)
  end

  #
  # annotations
  #

  def test_annotation_not_supported
    env, problems = instantiate(%Q(
      @annotation 
      TestNode
      ), TestMM)
    assert_problems([[/annotation not allowed/i, 3]], problems)
  end

  def test_annotation_not_allowed
    env, problems = instantiate(%Q(
      @annotation 
      TestNode
      ), TestMM, :annotation_handler => proc {|a,e,env|
        false
      })
    assert_problems([[/annotation not allowed/i, 3]], problems)
  end

  def test_annotation_in_wrong_places
    env, problems = instantiate(%Q(
      @annotation 
      #comment
      TestNode {
        @annotation
        childs:
          TestNode
          @annotation
      }
      @annotation
      ), TestMM)
    assert_problems([
      [/unexpected comment 'comment', expected identifier/i, 3],
      [/unexpected label 'childs', expected identifier/i, 6],
      [/unexpected \}, expected identifier/i, 9],
      [/unexpected end of file, expected identifier/i, 10]
    ], problems)
  end

  def test_annotation_handler
    annotations = []
    elements = [] 
    env, problems = instantiate(%Q(
      @annotation
      TestNode text: "aa"
      @annotation
      @ in a new line

      @ even with space in between

      TestNode text: "bb" {
        @at child
        TestNode text: "cc"
        childs:
          @after label
          TestNode text: "dd"
        @another child
        TestNode text: "ee"
        childs: [
          @in brackets
          TestNode text: "ff"
        ]
      }
      ), TestMM, :annotation_handler => proc {|a,e,env|
        annotations << a
        elements << e
        true
      })
    assert_equal "aa", elements[0].text
    assert_equal "annotation", annotations[0]
    assert_equal "cc", elements[1].text
    assert_equal "at child", annotations[1]
    assert_equal "dd", elements[2].text
    assert_equal "after label", annotations[2]
    assert_equal "ee", elements[3].text
    assert_equal "another child", annotations[3]
    assert_equal "ff", elements[4].text
    assert_equal "in brackets", annotations[4]
    assert_equal "bb", elements[5].text
    assert_equal "annotation\n in a new line\n even with space in between", annotations[5]
    assert_no_problems(problems)
  end

  #
  # generics
  #

  def test_generics_parse_error
    env, problems = instantiate(%Q(
      TestNode text: <bla
      TestNode text: bla>
      TestNode text: <a<b>
      TestNode text: <a>b>
      TestNode text: <%a
      TestNode text: <%a%
      TestNode text: <%a%>b%>
      ), TestMM, :enable_generics => true)
    assert_problems([
      [/parse error on token '<'/i, 2],
      [/unexpected unlabled argument/i, 2],
      [/parse error on token '>'/i, 3],
      [/unexpected identifier 'b'/i, 5],
      [/parse error on token '>'/i, 5],
      [/unexpected unlabled argument/i, 5],
      [/parse error on token '<'/i, 6],
      [/unexpected unlabled argument/i, 6],
      [/parse error on token '<'/i, 7],
      [/unexpected unlabled argument/i, 7],
      [/parse error on token '%'/i, 7],
      [/unexpected identifier 'b'/i, 8],
      [/unexpected unlabled argument/i, 8],
      [/parse error on token '%'/i, 8],
    ], problems)
  end

  def test_generics
    root_elements = []
    env, problems = instantiate(%q(
      TestNode text: <bla>, nums: [<1>, <%2%>], boolean: <truthy>, enum: <%option%>, float: <precise>, related: <%noderef%>, others: [<other1>, <%other2%>]
    ), TestMM, :root_elements => root_elements, :enable_generics => true)
    assert_no_problems(problems)
    assert root_elements[0].text.is_a?(RText::Generic)
    assert_equal "bla", root_elements[0].text.string
    assert_equal ["1", "2"], root_elements[0].nums.collect{|n| n.string}
    assert_equal "truthy", root_elements[0].boolean.string
    assert_equal "option", root_elements[0].enum.string
    assert_equal "precise", root_elements[0].float.string
    assert_equal "noderef", root_elements[0].related.string
    assert_equal ["other1", "other2"], root_elements[0].others.collect{|n| n.string}
  end

  def test_generics_forbidden
    env, problems = instantiate(%Q(\
      TestNode text: <bla>
      ), TestMM)
    assert_problems([
      [/generic value not allowed/i, 1],
    ], problems)
  end

  #
  # subpackages
  #

  def test_subpackage
    env, problems = instantiate(%q(
      TestNodeSub text: "something" 
    ), TestMMSubpackage)
    assert_no_problems(problems)
    assert_equal "something", env.elements.first.text
  end

  #
  # values
  # 

  def test_escapes
    env, problems = instantiate(%q(
      TestNode text: "some \" \\\\ \\\\\" text \r xx \n xx \r\n xx \t xx \b xx \f"
    ), TestMM)
    assert_no_problems(problems)
    assert_equal %Q(some " \\ \\" text \r xx \n xx \r\n xx \t xx \b xx \f), env.elements.first.text
  end

  def test_escape_single_backslash
    env, problems = instantiate(%q(
      TestNode text: "a single \\ will be just itself"
    ), TestMM)
    assert_no_problems(problems)
    assert_equal %q(a single \\ will be just itself), env.elements.first.text
  end

  def test_string_umlauts
    env, problems = instantiate(%q(
      TestNode text: "ä, ö, ü"
    ), TestMM)
    assert_no_problems(problems)
    assert_equal %q(ä, ö, ü), env.elements.first.text
  end

  def test_integer
    env, problems = instantiate(%q(
      TestNode integer: 7 
    ), TestMM)
    assert_no_problems(problems)
    assert_equal 7, env.elements.first.integer
  end

  def test_integer_hex
    env, problems = instantiate(%q(
      TestNode text: root {
        TestNode integer: 0x7 
        TestNode integer: 0X7 
        TestNode integer: 0x007 
        TestNode integer: 0x77
        TestNode integer: 0xabCDEF
      }
    ), TestMM)
    assert_no_problems(problems)
    assert_equal [7, 7, 7, 0x77, 0xABCDEF], env.find(:text => "root").first.childs.collect{|c| c.integer}
  end

  def test_float
    env, problems = instantiate(%q(
      TestNode float: 1.23 
      TestNode float: 1.23e-08 
      TestNode float: 1.23e+10 
      TestNode float: 1234567890.123456789
    ), TestMM)
    assert_no_problems(problems)
    assert_equal 1.23, env.elements[0].float
    assert_equal 1.23e-08, env.elements[1].float
    assert_equal 1.23e+10, env.elements[2].float
    if rgen_with_bigdecimal?
      assert env.elements[3].float.is_a?(BigDecimal)
      assert_equal "1234567890.123456789", env.elements[3].float.to_s("F")
    else
      assert env.elements[3].float.is_a?(Float)
      assert_equal "1234567890.1234567", env.elements[3].float.to_s
    end
  end

  def test_boolean
    env, problems = instantiate(%q(
      TestNode text: root {
        TestNode boolean: true 
        TestNode boolean: false 
      }
    ), TestMM)
    assert_no_problems(problems)
    assert_equal [true, false], env.find(:text => "root").first.childs.collect{|c| c.boolean}
  end

  def test_enum
    env, problems = instantiate(%q(
      TestNode text: root {
        TestNode enum: A 
        TestNode enum: B 
        TestNode enum: "non-word*chars"
        TestNode enum: "2you"
      }
    ), TestMM)
    assert_no_problems(problems)
    assert_equal [:A, :B, :'non-word*chars', :'2you'], env.find(:text => "root").first.childs.collect{|c| c.enum}
  end

  def test_with_bom
    env, problems = instantiate(%Q(\xEF\xBB\xBF
      TestNode text: "some text", nums: [1,2] {
        TestNode text: "child"
        TestNode text: "child2"
      }
      ), TestMM)
    assert_no_problems(problems)
    assert_model_simple(env, :with_nums)
  end

  #
  # conflicts with builtins
  # 

  def test_conflict_builtin
    env, problems = instantiate(%q(
      Data notTheBuiltin: "for sure" 
    ), TestMMData)
    assert_no_problems(problems)
    assert_equal "for sure", env.elements.first.notTheBuiltin
  end

  def test_builtin_in_subpackage
    env, problems = instantiate(%q(
      Data notTheBuiltin: "for sure" 
    ), TestMMSubpackage)
    assert_no_problems(problems)
    assert_equal "for sure", env.elements.first.notTheBuiltin
  end

  #
  # encoding
  #

  def test_encodings
    input = %Q(TestNode text: "iso-8859-1 AE Umlaut: \xc4")
    # force encoding to binary in order to prevent exceptions on invalid byte sequences
    # if the encoding would be utf-8, there would be an exception with the string above
    input.force_encoding("binary")
    env, problems = instantiate(input, TestMM)
    assert_no_problems(problems)
    assert_match /AE Umlaut: /, env.elements.first.text
  end

  private

  def instantiate(text, mm, options={})
    env = RGen::Environment.new
    lang = RText::Language.new(mm.ecore, options.merge(
      :root_classes => mm.ecore.eAllClasses.select{|c| 
        c.name == "TestNode" || c.name == "Data" || c.name == "TestNodeSub" || c.name == "SubNode"}))
    inst = RText::Instantiator.new(lang)
    problems = []
    inst.instantiate(text, options.merge({:env => env, :problems => problems, :root_elements => options[:root_elements]}))
    return env, problems
  end
  
  def assert_no_problems(problems)
    assert problems.empty?, problems.collect{|p| "#{p.message}, line: #{p.line}"}.join("\n")
  end

  def assert_problems(expected, problems)
    remaining = problems.dup
    probs = []
    expected.each do |e|
      if e.is_a?(Array)
        p = remaining.find{|p| p.message =~ e[0] && p.line == e[1]}
      else
        p = remaining.find{|p| p.message =~ e}
      end
      probs << "expected problem not present: #{e}" if !p
      # make sure to not delete duplicate problems at once
      idx = remaining.index(p)
      remaining.delete_at(idx) if idx
    end
    remaining.each do |p|
      probs << "unexpected problem: #{p.message}, line: #{p.line}"
    end
    assert probs.empty?, probs.join("\n")
  end

  def assert_model_simple(env, *opts)
    raise "unknown options" unless (opts - [:with_nums]).empty?
    root = env.find(:class => TestMM::TestNode, :text => "some text").first
    assert_not_nil root
    assert_equal 2, root.childs.size
    assert_equal [TestMM::TestNode, TestMM::TestNode], root.childs.collect{|c| c.class}
    assert_equal ["child", "child2"], root.childs.text
    if opts.include?(:with_nums)
      assert_equal [1, 2], root.nums
    end
  end

  def rgen_with_bigdecimal?
    begin
      TestMM::TestNode.new.float = BigDecimal.new("0.0")
    rescue StandardError
      return false
    end
    true
  end

end
	

