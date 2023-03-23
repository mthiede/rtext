# encoding: binary
$:.unshift(File.dirname(__FILE__)+"/../../lib")

require 'minitest/autorun'
require 'rtext/frontend/connector_manager'
require 'rtext/frontend/context'
require 'logger'

class IntegrationTest < MiniTest::Test

ModelFile = File.dirname(__FILE__)+"/model/test_metamodel.ect"
ModelFile2 = File.dirname(__FILE__)+"/model/test_metamodel2.ect"
ModelFile3 = File.dirname(__FILE__)+"/model/test_metamodel3.ect4"
LargeWithErrorsFile = File.dirname(__FILE__)+"/model/test_large_with_errors.ect3"
InvalidEncodingFile = File.dirname(__FILE__)+"/model/invalid_encoding.invenc"
NotInRTextFile = File.dirname(__FILE__)+"/model/test.not_in_rtext"
InvalidCmdLineFile = File.dirname(__FILE__)+"/model/test.invalid_cmd_line"
CrashingBackendFile = File.dirname(__FILE__)+"/model/test.crashing_backend"
DontOpenSocketFile = File.dirname(__FILE__)+"/model/test.dont_open_socket"
CrashOnRequestFile = File.dirname(__FILE__)+"/model/test.crash_on_request"

def setup_rtext_file(dir)
  include_args = $:.map { |p| "-I#{p}" }.join(' ')
  File.write(File.join(dir, '.rtext'), <<EOF
*.ect:
ruby #{include_args} ../ecore_editor.rb "*.ect" 2>&1
*.ect2:
ruby #{include_args} ../ecore_editor.rb "*.ect2" 2>&1
*.ect3:
ruby #{include_args} ../ecore_editor.rb "*.ect3" 2>&1
*.ect4:
ruby #{include_args} ../ecore_editor.rb "*.ect4" 2>&1
*.invenc:
ruby -E utf-8 #{include_args} ../ecore_editor.rb "*.invenc" 2>&1
*.invalid_cmd_line:
invalid_command_will_fail
*.crashing_backend:
ruby -e "this will crash"
*.dont_open_socket:
ruby -e "sleep(2)"
*.crash_on_request:
ruby #{include_args} ../crash_on_request_editor.rb "*.ect" 2>&1
EOF
  )
end

def setup_connector(file)
  setup_rtext_file(File.dirname(file))
  @infile = file
  outfile = File.dirname(__FILE__)+"/backend.out" + Random.new.rand(100000000).to_s
  logfile = File.dirname(__FILE__)+"/frontend.log"
  logger = Logger.new(logfile)
    File.unlink(outfile) if File.exist?(outfile)
  @connection_timeout = false
  man = RText::Frontend::ConnectorManager.new(
    :logger => logger,
    :keep_outfile => true,
    :connection_timeout => 10,
    :outfile_provider => lambda { File.expand_path(outfile) },
    :connect_callback => lambda do |connector, state|
      @connection_timeout = true if state == :timeout
    end)
  @con = man.connector_for_file(@infile)
end

def teardown
  @con.stop if @con
end

def test_non_existing_file
  setup_connector("this is not a file")
  assert_nil @con
end

def test_not_in_rtext_file
  setup_connector(NotInRTextFile)
  assert_nil @con
end

def test_invalid_command_line
  setup_connector(InvalidCmdLineFile)
  assert @con
  response = load_model
  assert @connection_timeout
end

def test_crashing_backend
  setup_connector(CrashingBackendFile)
  assert @con
  response = load_model
  assert @connection_timeout
end

def test_backend_doesnt_open_socket
  setup_connector(DontOpenSocketFile)
  assert @con
  response = load_model
  assert @connection_timeout
end

def test_backend_crash_on_request
  setup_connector(CrashOnRequestFile)
  assert @con
  response = load_model
  assert_equal [], response["problems"]
  response = @con.execute_command({"command" => "link_targets", "context" => [], "column" => 1})
  assert_equal :timeout, response
end

# simulate external encoding utf-8 (-E in .rext) containing a iso-8859-1 character
def test_invalid_encoding
  setup_connector(InvalidEncodingFile)
  response = load_model
  assert_equal "response", response["type"]
  assert_equal [], response["problems"]
  text = %Q(EPackage "iso-8859-1 umlaut: \xe4",| nsPrefix: "")
  context = build_context(text)
  assert_completions context, [
    "nsPrefix:",
    "nsURI:"
  ]
end

def test_loadmodel
  setup_connector(ModelFile)
  response = load_model
  assert_equal "response", response["type"]
  assert_equal [], response["problems"]
end

def test_loadmodel_large_with_errors
  setup_connector(LargeWithErrorsFile)
  response = load_model
  assert_equal "response", response["type"]
  assert_equal 43523, response["problems"].first["problems"].size
end

def test_unknown_command
  setup_connector(ModelFile)
  response = load_model
  response = @con.execute_command({"command" => "unknown"})
  assert_equal "unknown_command_error", response["type"]
end

#TODO: connector restart when .rtext file changes

def test_complete_first_line
  setup_connector(ModelFile)
  load_model
  context = build_context <<-END
|EPackage StatemachineMM {
  END
  assert_completions context, [
    "EPackage"
  ]
  context = build_context <<-END
EPackage| StatemachineMM {
  END
  assert_completions context, [
    "EPackage"
  ]
  context = build_context <<-END
EPackage |StatemachineMM {
  END
  assert_completions context, [
    "name",
    "nsPrefix:",
    "nsURI:"
  ]
  context = build_context <<-END
EPackage S|tatemachineMM {
  END
  assert_completions context, [
    "name",
    "nsPrefix:",
    "nsURI:"
  ]
  context = build_context <<-END
EPackage StatemachineMM| {
  END
  assert_completions context, [
    "name",
    "nsPrefix:",
    "nsURI:"
  ]
  context = build_context <<-END
EPackage StatemachineMM |{
  END
  assert_completions context, [
  ]
  context = build_context <<-END
EPackage StatemachineMM {|
  END
  # these columns don't exist
  assert_completions context, []
  context = build_context({:col => 27}, "EPackage StatemachineMM {")
  assert_completions context, []
  context = build_context({:col => 28}, "EPackage StatemachineMM {")
  assert_completions context, []
  context = build_context({:col => 100}, "EPackage StatemachineMM {")
  assert_completions context, []
  # before first column is like first column
  context = build_context({:col => 0}, "EPackage StatemachineMM {")
  assert_completions context, [
    "EPackage"
  ]
  context = build_context({:col => -1}, "EPackage StatemachineMM {")
  assert_completions context, [
    "EPackage"
  ]
  context = build_context({:col => -100}, "EPackage StatemachineMM {")
  assert_completions context, [
    "EPackage"
  ]
end

def test_nested_command
  setup_connector(ModelFile)
  load_model
  context = build_context <<-END
EPackage StatemachineMM {
|  EClass State, abstract: true {
  END
  assert_completions context, [
    "EAnnotation",
    "EClass",
    "EDataType",
    "EEnum",
    "EGenericType",
    "EPackage"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  |EClass State, abstract: true {
  END
  assert_completions context, [
    "EAnnotation",
    "EClass",
    "EDataType",
    "EEnum",
    "EGenericType",
    "EPackage"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EC|lass State, abstract: true {
  END
  assert_completions context, [
    "EAnnotation",
    "EClass",
    "EDataType",
    "EEnum",
    "EGenericType",
    "EPackage"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass| State, abstract: true {
  END
  assert_completions context, [
    "EAnnotation",
    "EClass",
    "EDataType",
    "EEnum",
    "EGenericType",
    "EPackage"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass |State, abstract: true {
  END
  assert_completions context, [
    "name",
    "abstract:",
    "interface:",
    "eSuperTypes:",
    "instanceClassName:"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass S|tate, abstract: true {
  END
  assert_completions context, [
    "name",
    "abstract:",
    "interface:",
    "eSuperTypes:",
    "instanceClassName:"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State|, abstract: true {
  END
  assert_completions context, [
    "name",
    "abstract:",
    "interface:",
    "eSuperTypes:",
    "instanceClassName:"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State,| abstract: true {
  END
  assert_completions context, [
    "abstract:",
    "interface:",
    "eSuperTypes:",
    "instanceClassName:"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, |abstract: true {
  END
  assert_completions context, [
    "abstract:",
    "interface:",
    "eSuperTypes:",
    "instanceClassName:"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, a|bstract: true {
  END
  assert_completions context, [
    "abstract:",
    "interface:",
    "eSuperTypes:",
    "instanceClassName:"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract:| true {
  END
  assert_completions context, [
    "true",
    "false"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: |true {
  END
  assert_completions context, [
    "true",
    "false"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: t|rue {
  END
  assert_completions context, [
    "true",
    "false"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true| {
  END
  assert_completions context, [
    "true",
    "false"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true |{
  END
  assert_completions context, [
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {|
  END
  assert_completions context, [
  ]
end

def test_complete_feature_after_linebreak
  setup_connector(ModelFile)
  load_model
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      |eType: /StatemachineMM/CompositeState,
  END
  assert_completions context, [
   "containment:",
   "resolveProxies:",
   "eOpposite:",
   "changeable:",
   "defaultValueLiteral:",
   "derived:",
   "transient:",
   "unsettable:",
   "volatile:",
   "lowerBound:",
   "ordered:",
   "unique:",
   "upperBound:",
   "eType:"
  ]
end

def test_complete_reference_after_linebreak
  setup_connector(ModelFile)
  load_model
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: |/StatemachineMM/CompositeState,
  END
  assert_completions context, [
    "/StatemachineMM/CompositeState",
    "/StatemachineMM/SimpleState",
    "/StatemachineMM/State",
    "/StatemachineMM/StringType",
    "/StatemachineMM/Transition",
    "/StatemachineMM2/SimpleState",
    "/StatemachineMM2/State"
  ]
end

def test_complete_command_after_linebreak
  setup_connector(ModelFile)
  load_model
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: /StatemachineMM/CompositeState,
      eOpposite: /StatemachineMM/CompositeState/substates
  }
  EClass SimpleState, eSuperTypes: [/StatemachineMM/State]
  EClass CompositeState,
    eSuperTypes: [
      /StatemachineMM/State
    ],
    abstract: false {
    |EReference substates, upperBound: -1, containment: true, eType: /StatemachineMM/State, eOpposite: /StatemachineMM/State/parent
  END
  assert_completions context, [
    "EAnnotation",
    "EAttribute",
    "EOperation",
    "EReference",
  ]
end

def test_complete_value_after_linebreak
  setup_connector(ModelFile)
  load_model
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: /StatemachineMM/CompositeState,
      eOpposite: /StatemachineMM/CompositeState/substates
  }
  EClass SimpleState, eSuperTypes: [/StatemachineMM/State]
  EClass CompositeState,
    eSuperTypes: [
      /StatemachineMM/State
    ],
    abstract: |false {
  END
  assert_completions context, [
    "true",
    "false"
  ]
end

def test_complete_in_array_after_linebreak
  setup_connector(ModelFile)
  load_model
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: /StatemachineMM/CompositeState,
      eOpposite: /StatemachineMM/CompositeState/substates
  }
  EClass SimpleState, eSuperTypes: [/StatemachineMM/State]
  EClass CompositeState,
    eSuperTypes: [
      |/StatemachineMM/State
  END
  assert_completions context, [
    "/StatemachineMM/CompositeState",
    "/StatemachineMM/SimpleState",
    "/StatemachineMM/State",
    "/StatemachineMM/Transition",
    "/StatemachineMM2/SimpleState",
    "/StatemachineMM2/State"
  ]
end

def test_complete_in_array_after_linebreak2
  setup_connector(ModelFile)
  load_model
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: /StatemachineMM/CompositeState,
      eOpposite: /StatemachineMM/CompositeState/substates
  }
  EClass SimpleState, eSuperTypes: [/StatemachineMM/State]
  EClass CompositeState,
    eSuperTypes: [
      /StatemachineMM/State
    |],
  END
  assert_completions context, [
  ]
end

def test_complete_after_backslash
  setup_connector(ModelFile3)
  load_model
  context = build_context <<-END
EPackage StatemachineMM3 {
  EClass State
  EClass \\
    |SimpleState,
  END
  assert_completions context, [
    "name",
    "abstract:",
    "interface:",
    "eSuperTypes:",
    "instanceClassName:"
  ]
end

def test_complete_after_backslash2
  setup_connector(ModelFile3)
  load_model
  context = build_context <<-END
EPackage StatemachineMM3 {
  EClass State
  EClass \\
    SimpleState,
    |eSuperTypes: [/StatemachineMM3/State]
  END
  assert_completions context, [
    "abstract:",
    "interface:",
    "eSuperTypes:",
    "instanceClassName:"
  ]
end

def test_link_target_after_backslash
  setup_connector(ModelFile3)
  load_model
  context = build_context <<-END
EPackage StatemachineMM3 {
  EClass State
  EClass \\
    SimpleState,
    eSuperTypes: [/S|tatemachineMM3/State]
  END
  assert_link_targets context, :file => ModelFile3, :begin => 44, :end => 65, :targets => [
    {"file"=> File.expand_path(ModelFile3),
     "line"=>2,
     "display"=>"/StatemachineMM3/State [EClass]"}
  ]
end

def test_reference_completion
  setup_connector(ModelFile)
  load_model
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: |/StatemachineMM/StringType
  END
  assert_completions context, [
    "/StatemachineMM/CompositeState",
    "/StatemachineMM/SimpleState",
    "/StatemachineMM/State",
    "/StatemachineMM/StringType",
    "/StatemachineMM/Transition",
    "/StatemachineMM2/SimpleState",
    "/StatemachineMM2/State",
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/|StringType
  END
  assert_completions context, [
    "/StatemachineMM/CompositeState",
    "/StatemachineMM/SimpleState",
    "/StatemachineMM/State",
    "/StatemachineMM/StringType",
    "/StatemachineMM/Transition",
    "/StatemachineMM2/SimpleState",
    "/StatemachineMM2/State",
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/St|ringType
  END
  assert_completions context, [
    "/StatemachineMM/CompositeState",
    "/StatemachineMM/SimpleState",
    "/StatemachineMM/State",
    "/StatemachineMM/StringType",
    "/StatemachineMM/Transition",
    "/StatemachineMM2/SimpleState",
    "/StatemachineMM2/State",
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType|
  END
  assert_completions context, [
    "/StatemachineMM/CompositeState",
    "/StatemachineMM/SimpleState",
    "/StatemachineMM/State",
    "/StatemachineMM/StringType",
    "/StatemachineMM/Transition",
    "/StatemachineMM2/SimpleState",
    "/StatemachineMM2/State",
  ]
end

def test_reference_completion_in_array
  setup_connector(ModelFile)
  load_model
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: /StatemachineMM/CompositeState,
      eOpposite: /StatemachineMM/CompositeState/substates
  }
  EClass SimpleState, eSuperTypes: [|/StatemachineMM/State]
  END
  assert_completions context, [
    "/StatemachineMM/CompositeState",
    "/StatemachineMM/SimpleState",
    "/StatemachineMM/State",
    "/StatemachineMM/Transition",
    "/StatemachineMM2/SimpleState",
    "/StatemachineMM2/State",
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: /StatemachineMM/CompositeState,
      eOpposite: /StatemachineMM/CompositeState/substates
  }
  EClass SimpleState, eSuperTypes: [/StatemachineMM/S|tate]
  END
  assert_completions context, [
    "/StatemachineMM/CompositeState",
    "/StatemachineMM/SimpleState",
    "/StatemachineMM/State",
    "/StatemachineMM/Transition",
    "/StatemachineMM2/SimpleState",
    "/StatemachineMM2/State",
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: /StatemachineMM/CompositeState,
      eOpposite: /StatemachineMM/CompositeState/substates
  }
  EClass SimpleState, eSuperTypes: [/StatemachineMM/State|]
  END
  assert_completions context, [
    "/StatemachineMM/CompositeState",
    "/StatemachineMM/SimpleState",
    "/StatemachineMM/State",
    "/StatemachineMM/Transition",
    "/StatemachineMM2/SimpleState",
    "/StatemachineMM2/State",
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: /StatemachineMM/CompositeState,
      eOpposite: /StatemachineMM/CompositeState/substates
  }
  EClass SimpleState, eSuperTypes: [/StatemachineMM/State]|
  END
  assert_completions context, [
  ]
end

def test_integer_completion
  setup_connector(ModelFile)
  load_model
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: /StatemachineMM/CompositeState,
      eOpposite: /StatemachineMM/CompositeState/substates
  }
  EClass SimpleState, eSuperTypes: [/StatemachineMM/State]
  EClass CompositeState,
    eSuperTypes: [
      /StatemachineMM/State
    ],
    abstract: false {
    EReference substates, upperBound: |-1, containment: true, eType: /StatemachineMM/State, eOpposite: /StatemachineMM/State/parent
  END
  assert_completions context, [
    "1",
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: /StatemachineMM/CompositeState,
      eOpposite: /StatemachineMM/CompositeState/substates
  }
  EClass SimpleState, eSuperTypes: [/StatemachineMM/State]
  EClass CompositeState,
    eSuperTypes: [
      /StatemachineMM/State
    ],
    abstract: false {
    EReference substates, upperBound: -1|, containment: true, eType: /StatemachineMM/State, eOpposite: /StatemachineMM/State/parent
  END
  assert_completions context, [
    "1",
  ]
end

def test_link_targets
  setup_connector(ModelFile)
  load_model
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /St|atemachineMM/StringType
  END
  assert_link_targets context, :begin => 29, :end => 54, :targets => [
    {"file"=> File.expand_path(@infile),
     "line"=>20,
     "display"=>"/StatemachineMM/StringType [EDataType]"}
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: |/StatemachineMM/StringType
  END
  assert_link_targets context, :begin => 29, :end => 54, :targets => [
    {"file"=> File.expand_path(@infile),
     "line"=>20,
     "display"=>"/StatemachineMM/StringType [EDataType]"}
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringTyp|e
  END
  assert_link_targets context, :begin => 29, :end => 54, :targets => [
    {"file"=> File.expand_path(@infile),
     "line"=>20,
     "display"=>"/StatemachineMM/StringType [EDataType]"}
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType|
  END
  assert_link_targets context, :begin => nil, :end => nil, :targets => []
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType:| /StatemachineMM/StringType
  END
  assert_link_targets context, :begin => nil, :end => nil, :targets => []
  # backward ref
  context = build_context <<-END
EPackage StatemachineMM {
  E|Class State, abstract: true {
  END
  assert_link_targets context, :begin => 3, :end => 8, :targets => [
    {"file"=> File.expand_path(@infile),
     "line"=>8,
     "display"=>"/StatemachineMM/SimpleState [EClass]"},
    {"file"=> File.expand_path(@infile),
     "line"=>9,
     "display"=>"/StatemachineMM/CompositeState [EClass]"}
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: /StatemachineMM/CompositeState,
      eOpposite: /StatemachineMM/CompositeState/substates
  }
  |EClass SimpleState, eSuperTypes: [/StatemachineMM/State]
  END
  assert_link_targets context, :begin => 3, :end => 8, :targets => []
  # bad location
  context = build_context <<-END
EPackage S|tatemachineMM {
  END
  assert_link_targets context, :begin => 10, :end => 23, :targets => []
end

def test_link_targets_no_text_after_name
  setup_connector(ModelFile)
  load_model
  context = build_context({:infile => ModelFile2}, <<-END
EPackage StatemachineMM2 {
  ECl|ass State
  END
  )
  assert_link_targets context, :file => ModelFile2, :begin => 3, :end => 8, :targets => [
    {"file"=> File.expand_path(ModelFile2),
     "line"=>3,
     "display"=>"/StatemachineMM2/SimpleState [EClass]"}
  ]
end

def test_link_targets_after_linebreak
  setup_connector(ModelFile)
  load_model
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: /St|atemachineMM/CompositeState,
  END
  # in case of linebreaks, the begin and end column refer to the string which
  # was passed to the backend as the context; in this case the context extractor
  # appends each broken line to the previous line with all the leading whitespace removed
  assert_link_targets context, :begin => 36, :end => 65, :targets => [
    {"file"=> File.expand_path(@infile),
     "line"=>9,
     "display"=>"/StatemachineMM/CompositeState [EClass]"}
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: |/StatemachineMM/CompositeState,
  END
  assert_link_targets context, :begin => 36, :end => 65, :targets => [
    {"file"=> File.expand_path(@infile),
     "line"=>9,
     "display"=>"/StatemachineMM/CompositeState [EClass]"}
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: /StatemachineMM/CompositeStat|e,
  END
  assert_link_targets context, :begin => 36, :end => 65, :targets => [
    {"file"=> File.expand_path(@infile),
     "line"=>9,
     "display"=>"/StatemachineMM/CompositeState [EClass]"}
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State, abstract: true {
    EAttribute name, eType: /StatemachineMM/StringType
    EReference parent,
      eType: /StatemachineMM/CompositeState|,
  END
  assert_link_targets context, :begin => nil, :end => nil, :targets => []
end

def test_find_elements
  setup_connector(ModelFile)
  load_model
  response = @con.execute_command(
    {"command" => "find_elements", "search_pattern" => "Sta"})
  assert_equal \
    [{"display"=>"State [EClass] - /StatemachineMM",
      "file"=> File.expand_path(@infile),
      "line"=>2},
     {"display"=>"State [EClass] - /StatemachineMM2",
      "file"=> File.expand_path(ModelFile2),
      "line"=>2},
     {"display"=>"StatemachineMM [EPackage] - /StatemachineMM",
      "file"=> File.expand_path(@infile),
      "line"=>1},
     {"display"=>"StatemachineMM2 [EPackage] - /StatemachineMM2",
      "file"=> File.expand_path(ModelFile2),
      "line"=>1}], response["elements"]
  response = @con.execute_command( 
    {"command" => "find_elements", "search_pattern" => "target"})
  assert_equal \
    [{"display"=>"target [EReference] - /StatemachineMM/Transition",
      "file"=> File.expand_path(@infile),
      "line"=>17}], response["elements"]
  response = @con.execute_command( 
    {"command" => "find_elements", "search_pattern" => ""})
  assert_equal [], response["elements"]
  response = @con.execute_command( 
    {"command" => "find_elements", "search_pattern" => "xxx"})
  assert_equal [], response["elements"]
end

TestContext = Struct.new(:line, :col)

def build_context(text, text2=nil)
  if text.is_a?(Hash)
    context_lines = text2.split("\n")
    pos_in_line = text[:col] || context_lines.last.index("|") + 1
    infile = text[:infile] || @infile
  else
    context_lines = text.split("\n")
    pos_in_line = context_lines.last.index("|") + 1
    infile = @infile
  end
  context_lines.last.sub!("|", "")

  # check that the context data actally matches the real file in the filesystem
  content = File.open(infile, "rb"){|f| f.read}
  ref_lines = content.split(/\r?\n/)[0..context_lines.size-1]
  raise "inconsistent test data, expected\n:#{ref_lines.join("\n")}\ngot:\n#{context_lines.join("\n")}" \
    unless ref_lines == context_lines

  # column numbers start at 1
  TestContext.new(context_lines.size, pos_in_line)
end

def assert_link_targets(context, options)
  infile = options[:file] || @infile
  content = File.open(infile, "rb") {|f| f.read}
  lines = content.split(/\r?\n/)[0..context.line-1]
  lines, col =  RText::Frontend::Context.new.extract(lines, context.col)
  response = @con.execute_command( 
    {"command" => "link_targets", "context" => lines, "column" => col})
  assert_equal "response", response["type"]
  assert_equal options[:targets], response["targets"]
  if options[:begin]
    assert_equal options[:begin], response["begin_column"]
  else
    assert_nil response["begin_column"]
  end
  if options[:end]
    assert_equal options[:end], response["end_column"]
  else
    assert_nil response["end_column"]
  end
end

def assert_completions(context, expected)
  content = File.open(@infile, "rb"){|f| f.read}
  lines = content.split(/\r?\n/)[0..context.line-1]
  lines, col =  RText::Frontend::Context.new.extract(lines, context.col)
  response = @con.execute_command( 
    {"command" => "content_complete", "context" => lines, "column" => col})
  assert_equal expected, response["options"].collect{|o| o["insert"]}
end

def load_model
  done = false
  response = nil
  while !done
    response = @con.execute_command({"command" => "load_model"})
    if response == :connecting && !@connection_timeout
      sleep(0.1)
    else
      done = true
    end
  end
  response
end

end
