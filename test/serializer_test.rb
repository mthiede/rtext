$:.unshift File.join(File.dirname(__FILE__),"..","lib")

gem 'minitest'
require 'minitest/autorun'
require 'bigdecimal'
require 'fileutils'
require 'stringio'
require 'rgen/environment'
require 'rgen/metamodel_builder'
require 'rtext/serializer'
require 'rtext/language'

class SerializerTest < MiniTest::Test
  TestOutputFile = ".serializer_test_file"

  def teardown
    FileUtils.rm_f TestOutputFile
  end

  class StringWriter < String
    alias write concat
  end

  module TestMM
    extend RGen::MetamodelBuilder::ModuleExtension
    SomeEnum = RGen::MetamodelBuilder::DataTypes::Enum.new(
      :name => "SomeEnum", :literals => [:A, :B, :'non-word*chars', :'2you'])
    class TestNode < RGen::MetamodelBuilder::MMBase
      has_attr 'text', String
      has_many_attr 'texts', String
      has_many_attr 'more_texts', String
      has_attr 'unlabled', String
      has_attr 'unquoted', String
      has_attr 'both', String
      has_attr 'none', String
      has_attr 'comment', String
      has_attr 'integer', Integer
      has_attr 'float', Float
      has_attr 'enum', SomeEnum
      has_attr 'boolean', Boolean
      contains_many 'childs', TestNode, 'parent'
    end
  end

  def test_simple
    testModel = TestMM::TestNode.new(:text => "some text", :childs => [
      TestMM::TestNode.new(:text => "child")])

    output = StringWriter.new
    serialize(testModel, TestMM, output)

    assert_equal %Q(\
TestNode text: "some text" {
  TestNode text: "child"
}
), output 
  end

  def test_many_attr
    testModel = TestMM::TestNode.new(:texts => ["a", "b", "c"])

    output = StringWriter.new
    serialize(testModel, TestMM, output)

    assert_equal %Q(\
TestNode texts: ["a", "b", "c"]
), output 
  end

  module TestMMFeatureProvider
    extend RGen::MetamodelBuilder::ModuleExtension
    class TestNode < RGen::MetamodelBuilder::MMBase
      has_attr 'attr1', String
      has_attr 'attr2', String
      has_attr 'attr3', String
      contains_many 'childs1', TestNode, 'parent1'
      contains_many 'childs2', TestNode, 'parent2'
      contains_many 'childs3', TestNode, 'parent3'
    end
  end

  def test_feature_provider
    testModel = TestMMFeatureProvider::TestNode.new(
      :attr1 => "attr1",
      :attr2 => "attr2",
      :attr3 => "attr3",
      :childs1 => [TestMMFeatureProvider::TestNode.new(:attr1 => "child1")],
      :childs2 => [TestMMFeatureProvider::TestNode.new(:attr1 => "child2")],
      :childs3 => [TestMMFeatureProvider::TestNode.new(:attr1 => "child3")])

    output = StringWriter.new
    serialize(testModel, TestMMFeatureProvider, output,
      :feature_provider => proc {|clazz| 
        clazz.eAllStructuralFeatures.reject{|f| f.name =~ /parent|2$/}.reverse})

    assert_equal %Q(\
TestNode attr3: "attr3", attr1: "attr1" {
  childs3:
    TestNode attr1: "child3"
  childs1:
    TestNode attr1: "child1"
}
), output 
  end

  module TestMMUnlabledUnquoted
    extend RGen::MetamodelBuilder::ModuleExtension
    class TestNode < RGen::MetamodelBuilder::MMBase
      has_attr 'unlabled', String
      has_attr 'unquoted', String
      has_attr 'both', String
      has_attr 'none', String
    end
  end

  def test_unlabled_unquoted
    testModel = [
      TestMMUnlabledUnquoted::TestNode.new(:unlabled => "unlabled", :unquoted => "unquoted", :both => "both", :none => "none"),
      TestMMUnlabledUnquoted::TestNode.new(:unquoted => "no identifier"),
      TestMMUnlabledUnquoted::TestNode.new(:unquoted => "true"),
      TestMMUnlabledUnquoted::TestNode.new(:unquoted => "333"),
      TestMMUnlabledUnquoted::TestNode.new(:unquoted => "33.3"),
      TestMMUnlabledUnquoted::TestNode.new(:unquoted => "5x"),
      TestMMUnlabledUnquoted::TestNode.new(:unquoted => "//")
    ]

    output = StringWriter.new
    serialize(testModel, TestMMUnlabledUnquoted, output,
      :unlabled_arguments => proc {|clazz| ["unlabled", "both"]},
      :unquoted_arguments => proc {|clazz| ["unquoted", "both"]}
    )

    assert_equal %Q(\
TestNode "unlabled", both, unquoted: unquoted, none: "none"
TestNode unquoted: "no identifier"
TestNode unquoted: "true"
TestNode unquoted: "333"
TestNode unquoted: "33.3"
TestNode unquoted: "5x"
TestNode unquoted: "//"
), output 
  end
  
  module TestMMComment
    extend RGen::MetamodelBuilder::ModuleExtension
    class TestNode < RGen::MetamodelBuilder::MMBase
      has_attr 'comment', String
      contains_many 'childs', TestNode, 'parent'
    end
  end

  def test_comment_provider
    testModel = TestMMComment::TestNode.new(
      :comment => "this is a comment",
      :childs => [
        TestMMComment::TestNode.new(:comment => "\n\ncomment of a child node\n  multiline\n\n\nanother\n\n\n"),
        TestMMComment::TestNode.new(:comment => "don't show"),
        TestMMComment::TestNode.new(:comment => "")])

    output = StringWriter.new
    serialize(testModel, TestMMComment, output,
      :comment_provider => proc { |e| 
        if e.comment != "don't show"
          c = e.comment
          e.comment = nil
          c
        else
          nil
        end
      })

    assert_equal %Q(\
#this is a comment
TestNode {
  #
  #
  #comment of a child node
  #  multiline
  #
  #
  #another
  TestNode
  TestNode comment: "don't show"
  TestNode
}
), output 
  end

  module TestMMAnnotation
    extend RGen::MetamodelBuilder::ModuleExtension
    class TestNode < RGen::MetamodelBuilder::MMBase
      has_attr 'annotation', String
      contains_many 'childs', TestNode, 'parent'
    end
  end

  def test_annotation_provider
    testModel = TestMMAnnotation::TestNode.new(
      :annotation => "this is an annotation",
      :childs => [
        TestMMAnnotation::TestNode.new(:annotation => "annotation of a child node\n  multiline"),
        TestMMAnnotation::TestNode.new(:annotation => "don't show")])

    output = StringWriter.new
    serialize(testModel, TestMMAnnotation, output,
      :annotation_provider => proc { |e| 
        if e.annotation != "don't show"
          a = e.annotation
          e.annotation = nil
          a
        else
          nil
        end
      })

    assert_equal %Q(\
@this is an annotation
TestNode {
  @annotation of a child node
  @  multiline
  TestNode
  TestNode annotation: "don't show"
}
), output 
  end

  def test_indent_string
    testModel = TestMM::TestNode.new(:childs => [
      TestMM::TestNode.new(:text => "child")])

    output = StringWriter.new
    serialize(testModel, TestMM, output, :indent_string => "____")

    assert_equal %Q(\
TestNode {
____TestNode text: "child"
}
), output 
  end

  module TestMMRef
    extend RGen::MetamodelBuilder::ModuleExtension
    class TestNode < RGen::MetamodelBuilder::MMBase
      has_attr 'name', String
      contains_many 'childs', TestNode, 'parent'
      has_many 'refMany', TestNode
      has_one 'refOne', TestNode
      one_to_many 'refManyBi', TestNode, 'refManyBack'
      one_to_one 'refOneBi', TestNode, 'refOneBack'
      many_to_many 'refManyMany', TestNode, 'refManyManyBack'
    end
  end

  def test_identifier_provider
    testModel = [
      TestMMRef::TestNode.new(:name => "Source"),
      TestMMRef::TestNode.new(:name => "Target")]
    testModel[0].refOne = testModel[1]

    output = StringWriter.new
    serialize(testModel, TestMMRef, output,
      :identifier_provider => proc{|e, context, feature, index| 
        assert_equal testModel[0], context
        assert_equal "refOne", feature.name
        assert_equal 0, index
        "/target/ref"
      }
    )

    assert_equal %Q(\
TestNode name: "Source", refOne: /target/ref
TestNode name: "Target"
),output
  end

  def test_identifier_provider_many
    testModel = [
      TestMMRef::TestNode.new(:name => "Source"),
      TestMMRef::TestNode.new(:name => "Target1"),
      TestMMRef::TestNode.new(:name => "Target2")]
    testModel[0].addRefMany(testModel[1])
    testModel[0].addRefMany(testModel[2])

    output = StringWriter.new
    call_index = 0
    serialize(testModel, TestMMRef, output,
      :identifier_provider => proc{|e, context, feature, index| 
        assert_equal testModel[0], context
        assert_equal "refMany", feature.name
        if call_index == 0
          call_index += 1
          assert_equal 0, index
          "/target/ref1"
        else
          assert_equal 1, index
          "/target/ref2"
        end
      }
    )
    assert_equal %Q(\
TestNode name: "Source", refMany: [/target/ref1, /target/ref2]
TestNode name: "Target1"
TestNode name: "Target2"
),output
  end

  def test_identifier_provider_nil
    testModel = [
      TestMMRef::TestNode.new(:name => "Source"),
      TestMMRef::TestNode.new(:name => "Target")]
    testModel[0].refOne = testModel[1]

    output = StringWriter.new
    serialize(testModel, TestMMRef, output,
      :identifier_provider => proc{|e, context, feature, index| 
        nil
      }
    )

    assert_equal %Q(\
TestNode name: "Source"
TestNode name: "Target"
),output
  end

  def test_references
    testModel = [ 
      TestMMRef::TestNode.new(:name => "Source"),
      TestMMRef::TestNode.new(:name => "Target",
        :childs => [
          TestMMRef::TestNode.new(:name => "A",
          :childs => [
            TestMMRef::TestNode.new(:name => "A1")
          ]),
          TestMMRef::TestNode.new(:name => "B"),
        ])
    ]
    testModel[0].refOne = testModel[1].childs[0].childs[0]
    testModel[0].refOneBi = testModel[1].childs[0].childs[0]
    testModel[0].refMany = [testModel[1].childs[0], testModel[1].childs[1]]
    testModel[0].refManyBi = [testModel[1].childs[0], testModel[1].childs[1]]
    testModel[0].refManyMany = [testModel[1].childs[0], testModel[1].childs[1]]
    testModel[0].addRefMany(RGen::MetamodelBuilder::MMProxy.new("/some/ref"))

    output = StringWriter.new
    serialize(testModel, TestMMRef, output)

    assert_equal %Q(\
TestNode name: "Source", refMany: [/Target/A, /Target/B, /some/ref], refOne: /Target/A/A1, refOneBi: /Target/A/A1
TestNode name: "Target" {
  TestNode name: "A", refManyBack: /Source, refManyManyBack: /Source {
    TestNode name: "A1"
  }
  TestNode name: "B", refManyBack: /Source, refManyManyBack: /Source
}
), output
  end

  module TestMMChildRole
    extend RGen::MetamodelBuilder::ModuleExtension
    class TestNodeA < RGen::MetamodelBuilder::MMBase
      has_attr 'text', String
    end
    class TestNodeB < RGen::MetamodelBuilder::MMBase
      has_attr 'text', String
    end
    class TestNodeC < RGen::MetamodelBuilder::MMBase
      has_attr 'text', String
    end
    class TestNodeD < RGen::MetamodelBuilder::MMBase
      has_attr 'text3', String
    end
    class TestNodeE < RGen::MetamodelBuilder::MMMultiple(TestNodeC, TestNodeD)
      has_attr 'text2', String
    end
    class TestNode < RGen::MetamodelBuilder::MMBase
      has_attr 'text', String
      has_many_attr 'texts', String
      contains_one 'child1', TestNode, 'parent1'
      contains_many 'childs2', TestNode, 'parent2'
      contains_one 'child3', TestNodeA, 'parent3'
      contains_many 'childs4', TestNodeB, 'parent4'
      contains_one 'child5', TestNodeC, 'parent5'
      contains_many 'childs6', TestNodeD, 'parent6'
      contains_one 'child7', TestNodeE, 'parent7'
    end
  end

  def test_child_role
    testModel = TestMMChildRole::TestNode.new(
      :child1 => TestMMChildRole::TestNode.new(:text => "child1"),
      :childs2 => [
        TestMMChildRole::TestNode.new(:text => "child2a"),
        TestMMChildRole::TestNode.new(:text => "child2b")
      ],
      :child3 => TestMMChildRole::TestNodeA.new(:text => "child3"),
      :childs4 => [TestMMChildRole::TestNodeB.new(:text => "child4")],
      :child5 => TestMMChildRole::TestNodeC.new(:text => "child5"),
      :childs6 => [TestMMChildRole::TestNodeD.new(:text3 => "child6"), TestMMChildRole::TestNodeE.new(:text => "child6.1")],
      :child7 => TestMMChildRole::TestNodeE.new(:text2 => "child7")
      )

    output = StringWriter.new
    serialize(testModel, TestMMChildRole, output)

    assert_equal %Q(\
TestNode {
  child1:
    TestNode text: "child1"
  childs2: [
    TestNode text: "child2a"
    TestNode text: "child2b"
  ]
  TestNodeA text: "child3"
  TestNodeB text: "child4"
  TestNodeC text: "child5"
  childs6: [
    TestNodeD text3: "child6"
    TestNodeE text: "child6.1"
  ]
  child7:
    TestNodeE text2: "child7"
}
), output 
  end

  module TestMMLabeledContainment
    extend RGen::MetamodelBuilder::ModuleExtension
    class TestNode < RGen::MetamodelBuilder::MMBase
      abstract
      has_attr 'text', String
      contains_many 'childs', TestNode, 'parent'
    end
    class TestNode1 < TestNode
    end
    class TestNode2 < TestNode
    end
  end

  def test_labeled_containment
    testModel = TestMMLabeledContainment::TestNode1.new(:text => "some text", :childs => [
      TestMMLabeledContainment::TestNode2.new(:text => "child", :childs => [
      TestMMLabeledContainment::TestNode1.new(:text => "nested child")
      ])])

    output = StringWriter.new
    serialize(testModel, TestMMLabeledContainment, output, :labeled_containments => proc {|c|
      if c == TestMMLabeledContainment::TestNode2.ecore
        ["childs"]
      else
        []
      end
    })

    assert_equal %Q(\
TestNode1 text: "some text" {
  TestNode2 text: "child" {
    childs:
      TestNode1 text: "nested child"
  }
}
), output 
  end

  def test_escapes
    testModel = TestMM::TestNode.new(:text => %Q(some " \\ \\" text \r xx \n xx \r\n xx \t xx \b xx \f))
    output = StringWriter.new
    serialize(testModel, TestMM, output) 

    assert_equal %q(TestNode text: "some \" \\\\ \\\\\" text \r xx \n xx \r\n xx \t xx \b xx \f")+"\n", output
  end

  def test_integer
    testModel = TestMM::TestNode.new(:integer => 7)
    output = StringWriter.new
    serialize(testModel, TestMM, output) 
    assert_equal %q(TestNode integer: 7)+"\n", output
  end

  def test_integer_big
    testModel = TestMM::TestNode.new(:integer => 12345678901234567890)
    output = StringWriter.new
    serialize(testModel, TestMM, output) 
    assert_equal %q(TestNode integer: 12345678901234567890)+"\n", output
  end

  def test_integer_format_spec
    testModel = TestMM::TestNode.new(:integer => 10)
    output = StringWriter.new
    serialize(testModel, TestMM, output, :argument_format_provider => proc {|a|
      if a.name == "integer"
        "0x%02X"
      else
        nil
      end}) 
    assert_equal %q(TestNode integer: 0x0A)+"\n", output
  end

  def test_integer_format_spec_big
    testModel = TestMM::TestNode.new(:integer => 0xabcdefabcdefabcdef)
    output = StringWriter.new
    serialize(testModel, TestMM, output, :argument_format_provider => proc {|a|
      if a.name == "integer"
        "0x%x"
      else
        nil
      end}) 
    assert_equal %q(TestNode integer: 0xabcdefabcdefabcdef)+"\n", output
  end

  def test_float
    testModel = TestMM::TestNode.new(:float => 1.23)
    output = StringWriter.new
    serialize(testModel, TestMM, output) 
    assert_equal %q(TestNode float: 1.23)+"\n", output 
  end

  def test_float2
    testModel = TestMM::TestNode.new(:float => 1.23e-08)
    output = StringWriter.new
    serialize(testModel, TestMM, output) 
    assert output =~ /TestNode float: 1.23e-0?08\n/ 
  end

  def test_float_format_spec
    testModel = TestMM::TestNode.new(:float => 1.23)
    output = StringWriter.new
    serialize(testModel, TestMM, output, :argument_format_provider => proc {|a|
      if a.name == "float"
        "%1.1f"
      else
        nil
      end}) 
    assert_equal %q(TestNode float: 1.2)+"\n", output
  end

  def test_float_big_decimal
    begin
      testModel = TestMM::TestNode.new(:float => BigDecimal.new("1234567890.123456789"))
    rescue StandardError
      return
    end
    output = StringWriter.new
    serialize(testModel, TestMM, output) 
    assert_equal %q(TestNode float: 1234567890.123456789)+"\n", output 
  end

  def test_enum
    testModel = [
      TestMM::TestNode.new(:enum => :A),
      TestMM::TestNode.new(:enum => :B),
      TestMM::TestNode.new(:enum => :'non-word*chars'),
      TestMM::TestNode.new(:enum => :'2you')
    ]
    output = StringWriter.new
    serialize(testModel, TestMM, output) 
    assert_equal %Q(\
TestNode enum: A
TestNode enum: B
TestNode enum: "non-word*chars"
TestNode enum: "2you"
), output
  end

  def test_generic
    testModel = [
      TestMM::TestNode.new(:text => RText::Generic.new("some text angel >bracket")),
      TestMM::TestNode.new(:text => RText::Generic.new("some text percent angel %>bracket")),
      TestMM::TestNode.new(:text => RText::Generic.new("some text > percent angel%>bracket")),
      TestMM::TestNode.new(:integer => RText::Generic.new("a number: 1")),
      TestMM::TestNode.new(:float => RText::Generic.new("precision")),
      TestMM::TestNode.new(:enum => RText::Generic.new("an option")),
      TestMM::TestNode.new(:boolean => RText::Generic.new("falsy"))
    ]
    output = StringWriter.new
    serialize(testModel, TestMM, output) 
    assert_equal %Q(\
TestNode text: <%some text angel >bracket%>
TestNode text: <some text percent angel >
TestNode text: <%some text > percent angel%>
TestNode integer: <a number: 1>
TestNode float: <precision>
TestNode enum: <an option>
TestNode boolean: <falsy>
), output
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
      class Data < RGen::MetamodelBuilder::MMBase
        has_attr 'notTheBuiltin', String
      end
      class Data2 < RGen::MetamodelBuilder::MMBase
        has_attr 'data2', String
      end
    end
  end

  def test_subpackage
    testModel = TestMMSubpackage::SubPackage::Data2.new(:data2 => "xxx")
    output = StringWriter.new
    serialize(testModel, TestMMSubpackage, output) 
    assert_equal %q(Data2 data2: "xxx")+"\n", output
  end

  def test_command_name_provider
    testModel = TestMM::TestNode.new(:text => "some text", :childs => [
      TestMM::TestNode.new(:text => "child")])

    output = StringWriter.new
    serialize(testModel, TestMM, output, :command_name_provider => proc do |c|
      c.name + "X"
    end)

    assert_equal %Q(\
TestNodeX text: "some text" {
  TestNodeX text: "child"
}
), output 
  end

  def test_file_output
    testModel = TestMM::TestNode.new(:text => "some text")

    File.open(TestOutputFile, "w") do |f|
      serialize(testModel, TestMM, f)
    end

    assert_equal %Q(\
TestNode text: "some text"
), File.read(TestOutputFile)
  end

  def test_stringio_output
    testModel = TestMM::TestNode.new(:text => "some text")

    output = StringIO.new
    serialize(testModel, TestMM, output)

    assert_equal %Q(\
TestNode text: "some text"
), output.string
  end

  #
  # line breaks
  #
  All_features = proc {|clazz|
    res = []
    clazz.eAllStructuralFeatures.reject{|f| f.name =~ /parent|2$/}.each{|f| res << f.name}
    res
  }

  def test_linebreak
    testModel = TestMM::TestNode.new(
      :text => "some text",
      :texts => ["some more text", "some more text", "some more text"])

    output = StringWriter.new
    serialize(testModel, TestMM, output,
      :newline_arguments => All_features,
      :newline_arrays => All_features)

    assert_equal %Q(\
TestNode \\
  text: "some text",
  texts: [
    "some more text",
    "some more text",
    "some more text"
  ]
), output 
  end

  def test_linebreak_child
    testModel1 = TestMM::TestNode.new(
      :text => "some text1",
      :texts => ["some more text", "some more text", "some more text"])
    testModel0 = TestMM::TestNode.new(
      :text => "some text0",
      :integer => 10,
      :childs => [testModel1])

    output = StringWriter.new
    serialize(testModel0, TestMM, output,
      :newline_arguments => All_features,
      :newline_arrays => All_features)

    assert_equal %Q(\
TestNode \\
  text: "some text0",
  integer: 10 {
    TestNode \\
      text: "some text1",
      texts: [
        "some more text",
        "some more text",
        "some more text"
      ]
}
), output 
  end

  def test_linebreak_child_no_arguments
    testModel1 = TestMM::TestNode.new(
      :text => "some text1",
      :texts => ["some more text", "some more text", "some more text"])
    testModel0 = TestMM::TestNode.new(:childs => [testModel1])

    output = StringWriter.new
    serialize(testModel0, TestMM, output,
      :newline_arguments => All_features,
      :newline_arrays => All_features)

    assert_equal %Q(\
TestNode {
  TestNode \\
    text: "some text1",
    texts: [
      "some more text",
      "some more text",
      "some more text"
    ]
}
), output 
  end

  def test_linebreak_unlabled_array_arguments
    testModel = TestMM::TestNode.new(
      :none => "some text",
      :texts => ["some more text", "some more text", "some more text"])

    output = StringWriter.new
    serialize(testModel, TestMM, output,
      :unlabled_arguments => proc {|clazz| ["texts"]},
      :newline_arguments => proc {|clazz| All_features.call(clazz) - ["texts"]},
      :newline_arrays => All_features)

    assert_equal %Q(\
TestNode [
    "some more text",
    "some more text",
    "some more text"
  ],
  none: "some text"
), output 
  end

  def test_linebreak_unlabled_array_arguments_sameline
    testModel = TestMM::TestNode.new(
      :none => "some text",
      :texts => ["some more text", "some more text", "some more text"])

    output = StringWriter.new
    serialize(testModel, TestMM, output,
      :unlabled_arguments => proc {|clazz| ["texts"]},
      :newline_arguments => proc {|clazz| All_features.call(clazz) - ["texts"]},
      :newline_arrays => proc {|clazz| All_features.call(clazz) - ["texts"]})

    assert_equal %Q(\
TestNode ["some more text", "some more text", "some more text"],
  none: "some text"
), output 
  end

  def test_linebreak_unlabled_both_arguments_and_child
    testModel1 = TestMM::TestNode.new(
      :texts => ["some more text", "some more text", "some more text"])
    testModel0 = TestMM::TestNode.new(
      :unlabled => "unlabled",
      :both => "both",
      :childs => [testModel1])

    output = StringWriter.new
    serialize(testModel0, TestMM, output,
      :unlabled_arguments => proc {|clazz| ["unlabled", "both"]},
      :unquoted_arguments => proc {|clazz| ["both"]},
      :newline_arguments => proc {|clazz| All_features.call(clazz) - ["unlabled"]},
      :newline_arrays => All_features)

    assert_equal %Q(\
TestNode "unlabled",
  both {
    TestNode \\
      texts: [
        "some more text",
        "some more text",
        "some more text"
      ]
}
), output 
  end

  def test_linebreak_child_two_attributes
    testModel1 = TestMM::TestNode.new(
      :text => "some text1",
      :texts => ["some more text", "some more text", "some more text"],
      :more_texts => ["even more text", "even more text"])
    testModel0 = TestMM::TestNode.new(:text => "some text0", :childs => [testModel1])

    output = StringWriter.new
    serialize(testModel0, TestMM, output,
      :newline_arguments => proc {|clazz| All_features.call(clazz) - ["text"]},
      :newline_arrays => proc {|clazz| All_features.call(clazz) - ["text"]})

    assert_equal %Q(\
TestNode text: "some text0" {
  TestNode text: "some text1",
    texts: [
      "some more text",
      "some more text",
      "some more text"
    ],
    more_texts: [
      "even more text",
      "even more text"
    ]
}
), output 
  end

  def test_linebreak_child_two_attributes_one_sameline
    testModel1 = TestMM::TestNode.new(
      :text => "some text1",
      :texts => ["some more text", "some more text", "some more text"],
      :more_texts => ["even more text", "even more text"])
    testModel0 = TestMM::TestNode.new(:text => "some text0", :childs => [testModel1])

    output = StringWriter.new
    serialize(testModel0, TestMM, output,
      :newline_arguments => proc {|clazz| All_features.call(clazz) - ["more_texts"]},
      :newline_arrays => proc {|clazz| All_features.call(clazz) - ["more_texts"]})

    assert_equal %Q(\
TestNode \\
  text: "some text0" {
    TestNode \\
      text: "some text1",
      texts: [
        "some more text",
        "some more text",
        "some more text"
      ], more_texts: ["even more text", "even more text"]
}
), output 
  end

  def test_linebreak_two_children
    testModel2 = TestMM::TestNode.new(:text => "some text2", :texts => ["some more text"])
    testModel1 = TestMM::TestNode.new(:text => "some text1", :texts => ["some more text", "some more text", "some more text"])
    testModel0 = TestMM::TestNode.new(:text => "some text0", :childs => [testModel1, testModel2])

    output = StringWriter.new
    serialize(testModel0, TestMM, output,
      :newline_arguments => proc {|clazz| All_features.call(clazz) - ["text"]},
      :newline_arrays => All_features)

    assert_equal %Q(\
TestNode text: "some text0" {
  TestNode text: "some text1",
    texts: [
      "some more text",
      "some more text",
      "some more text"
    ]
  TestNode text: "some text2",
    texts: "some more text"
}
), output 
  end

  def test_linebreak_nested_children
    testModel2 = TestMM::TestNode.new(
      :text => "some text2",
      :texts => ["some more text", "some more text", "some more text"])
    testModel1 = TestMM::TestNode.new(
      :text => "some text1",
      :childs => [testModel2])
    testModel0 = TestMM::TestNode.new(
      :text => "some text0",
      :integer => 10,
      :childs => [testModel1])

    output = StringWriter.new
    serialize(testModel0, TestMM, output,
      :newline_arguments => All_features,
      :newline_arrays => All_features)

    assert_equal %Q(\
TestNode \\
  text: "some text0",
  integer: 10 {
    TestNode \\
      text: "some text1" {
        TestNode \\
          text: "some text2",
          texts: [
            "some more text",
            "some more text",
            "some more text"
          ]
    }
}
), output 
  end

  def test_linebreak_no_break
    testModel = TestMM::TestNode.new(:text => "some text", :texts => ["some more text", "some more text", "some more text"])

    output = StringWriter.new
    serialize(testModel, TestMM, output)

    assert_equal %Q(\
TestNode text: "some text", texts: ["some more text", "some more text", "some more text"]
), output 
  end

  def test_linebreak_child_role
    testModel = TestMMChildRole::TestNode.new(
      :child1 => TestMMChildRole::TestNode.new(:text => "child1"),
      :childs2 => [
        TestMMChildRole::TestNode.new(
          :text => "child2a",
          :texts => ["some more text", "some more text"]),
        TestMMChildRole::TestNode.new(
          :text => "child2b",
          :texts => ["some more text", "some more text"])
      ])

    output = StringWriter.new
    serialize(testModel, TestMMChildRole, output,
      :newline_arguments => proc {|clazz| All_features.call(clazz) - ["text"]},
      :newline_arrays => proc {|clazz| All_features.call(clazz) - ["text"]})

    assert_equal %Q(\
TestNode {
  child1:
    TestNode text: "child1"
  childs2: [
    TestNode text: "child2a",
      texts: [
        "some more text",
        "some more text"
      ]
    TestNode text: "child2b",
      texts: [
        "some more text",
        "some more text"
      ]
  ]
}
), output 
  end

  def test_linebreak_comment
    testModel = TestMM::TestNode.new(
      :text => "some text",
      :comment => "this is a comment",
      :childs => [
        TestMM::TestNode.new(:comment => "\n\ncomment of a child node\n  multiline\n\n\nanother\n\n\n")
        ])

    output = StringWriter.new
    serialize(testModel, TestMM, output,
      :newline_arguments => All_features,
      :comment_provider => proc { |e| 
        c = e.comment
        e.comment = nil
        c
      })

    assert_equal %Q(\
#this is a comment
TestNode \\
  text: "some text" {
    #
    #
    #comment of a child node
    #  multiline
    #
    #
    #another
    TestNode
}
), output 
  end

  module TestMMObjectAttribute
    extend RGen::MetamodelBuilder::ModuleExtension
    class TestNode < RGen::MetamodelBuilder::MMBase
      has_many_attr 'objs', Object
    end
  end

  def test_object_attribute
    testModel = TestMMObjectAttribute::TestNode.new(
        :objs => ['some text', -123, :someSymbol, true, false, -0.097, :'some other symbol'])

    output = StringWriter.new
    serialize(testModel, TestMMObjectAttribute, output)

    assert_equal %Q(\
TestNode objs: ["some text", -123, someSymbol, true, false, -0.097, "some other symbol"]
), output
  end

  def serialize(model, mm, output, options={})
    lang = RText::Language.new(mm.ecore, options)
    ser = RText::Serializer.new(lang)
    ser.serialize(model, output)
  end

end

