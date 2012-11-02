$:.unshift(File.dirname(__FILE__)+"/../../lib")
require 'test/unit'
require 'rtext/frontend/connector_manager'
require 'rtext/frontend/context'
require 'logger'

class IntegrationTest < Test::Unit::TestCase

def setup
  @infile = File.dirname(__FILE__)+"/model/test_metamodel.ect"
  outfile = File.dirname(__FILE__)+"/outfile"
  logger = Logger.new($stdout)
  man = RText::Frontend::ConnectorManager.new(
    :logger => logger,
    :keep_outfile => true,
    :outfile_provider => lambda { File.expand_path(outfile) })
  @con = man.connector_for_file(@infile)
end

def teardown
  puts "stopping"
  @con.stop
  sleep(1)
end

def test_loadmodel
  response = load_model
  assert_equal "response", response["type"]
  assert_equal [], response["problems"]
end

def test_unknown_command
  response = load_model
  response = @con.execute_command({"command" => "unknown"})
  assert_equal "unknown_command_error", response["type"]
end

#TODO: connection timeout, backend crash during command execution

def test_complete_first_line
  response = load_model
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
    "<name>",
    "nsPrefix:",
    "nsURI:"
  ]
  context = build_context <<-END
EPackage S|tatemachineMM {
  END
  assert_completions context, []
  context = build_context <<-END
EPackage StatemachineMM| {
  END
  assert_completions context, []
  context = build_context <<-END
EPackage StatemachineMM |{
  END
  assert_completions context, [
    "nsPrefix:",
    "nsURI:"
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
  response = load_model
  context = build_context <<-END
EPackage StatemachineMM {
|  EClass State, abstract: true {
  END
  assert_completions context, [
    "EAnnotation",
    "EClass",
    "EClassifier",
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
    "EClassifier",
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
    "EClass",
    "EClassifier"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass| State, abstract: true {
  END
  assert_completions context, [
    "EClass",
    "EClassifier"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass |State, abstract: true {
  END
  assert_completions context, [
    "<name>", 
    "abstract:", 
    "interface:", 
    "eSuperTypes:", 
    "instanceClassName:"
  ]
  context = build_context <<-END
EPackage StatemachineMM {
  EClass S|tate, abstract: true {
  END
  assert_completions context, []
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State|, abstract: true {
  END
  assert_completions context, []
  context = build_context <<-END
EPackage StatemachineMM {
  EClass State,| abstract: true {
  END
  assert_completions context, []
end

TestContext = Struct.new(:line, :col)

def build_context(text, text2=nil)
  if text.is_a?(Hash)
    context_lines = text2.split("\n")
    pos_in_line = text[:col]
  else
    context_lines = text.split("\n")
    pos_in_line = context_lines.last.index("|") + 1
  end
  context_lines.last.sub!("|", "")

  # check that the context data actally matches the real file in the filesystem
  ref_lines = File.read(@infile).split(/\r?\n/)
  assert_equal ref_lines[0..context_lines.size-1], context_lines, "inconsistent test data"

  # column numbers start at 1
  TestContext.new(context_lines.size, pos_in_line)
end

def assert_completions(context, expected)
  lines = File.read(@infile).split(/\r?\n/)[0..context.line-1]
  response = @con.execute_command( 
    {"command" => "content_complete", "context" => lines, "column" => context.col})
  assert_equal expected, response["options"].collect{|o| o["insert"]}
end

def load_model
  done = false
  response = nil
  while !done 
    response = @con.execute_command({"command" => "load_model"})
    puts response.inspect
    if response == :connecting
      sleep(0.1)
      @con.resume
    else
      done = true
    end
  end
  response
end

end
