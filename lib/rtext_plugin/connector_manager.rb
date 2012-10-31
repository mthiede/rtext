require 'digest'
require 'rtext_plugin/config'
require 'rtext_plugin/connector'

module RTextPlugin

class ConnectorManager

def initialize(options={})
  @logger = options[:logger]
  @connector_descs = {}
  @connector_listener = options[:on_connect]
end

ConnectorDesc = Struct.new(:connector, :checksum)

def connector_for_file(file)
  config = Config.find_service_config(file)
  if config
    file_pattern = Config.file_pattern(file)
    key = desc_key(config, file_pattern)
    desc = @connector_descs[key]
    if desc
      if desc.checksum == config_checksum(config)
        desc.connector
      else
        # connector must be replaced
        desc.connector.stop
        create_connector(config, file_pattern) 
      end
    else
      create_connector(config, file_pattern)
    end
  else
    nil
  end
end

def all_connectors
  @connector_descs.values.collect{|v| v.connector}
end

private

def create_connector(config, pattern)
  con = Connector.new(config, :logger => @logger, :on_connect => lambda do
    @connector_listener.call(con) if @connector_listener
  end)
  desc = ConnectorDesc.new(con, config_checksum(config))
  key = desc_key(config, pattern)
  @connector_descs[key] = desc
  desc.connector
end

def desc_key(config, pattern)
  config.file + "," + pattern
end

def config_checksum(config)
  if File.exist?(config.file)
    sha1 = Digest::SHA1.new
    sha1.file(config.file)
    sha1.hexdigest
  else
    nil
  end
end


end

end

