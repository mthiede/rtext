require 'optparse'
require 'logger'
require 'rgen/ecore/ecore'
require 'rgen/environment'
require 'rgen/fragment/fragmented_model'
require 'rtext/default_loader'
require 'rtext/default_service_provider'
require 'rtext/service'
require 'rtext/language'

$stdout.sync = true

parser = OptionParser.new do |opts|
  opts.banner = "ecore-editor.rb <file patterns>"
end
begin
  parser.parse!
rescue OptionParser::InvalidArgument => e
  abort e.to_s
end

dirs = ARGV
abort "no input dirs" unless dirs.size > 0 

logger = Logger.new($stdout)
class << logger
  def format_message(severity, timestamp, progname, msg)
    "[#{timestamp.strftime("%H:%M:%S")}] #{severity} #{msg}\n"
  end
end

module RGen::ECore::EModelElement::ClassModule
  attr_accessor :line_number, :fragment_ref
end

mm = RGen::ECore.ecore
lang = RText::Language.new(mm, 
  :root_classes => [RGen::ECore::EPackage.ecore],
  :unlabled_arguments => lambda {|c| ["name"] },
  :line_number_attribute => "line_number",
  :fragment_ref_attribute => "fragment_ref"
)

model = RGen::Fragment::FragmentedModel.new(:env => RGen::Environment.new)
loader = RText::DefaultLoader.new(lang, model, :pattern => dirs)
service_provider = RText::DefaultServiceProvider.new(lang, model, loader)

service = RText::Service.new(lang, service_provider, :logger => logger, :timeout => 3600)
service.run
