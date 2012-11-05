$:.unshift(File.dirname(__FILE__))
require 'rtext/default_service_provider'

# monkey patch to produce a crash

class RText::DefaultServiceProvider
  def get_reference_targets(identifier, context)
    raise "crash"
  end
end

require 'ecore_editor'
