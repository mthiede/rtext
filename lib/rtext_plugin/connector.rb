require 'socket'
require 'open3'
require 'tmpdir'

module RTextPlugin

class Connector
include Process

InvocationDescriptor = Struct.new(:proc, :result)

def initialize(config, logger)
  @config = config
  @logger = logger
  @state = :off
  @invocation_id = 1
  @invocations = {}
  @busy = false
end

def execute_command(command, params=[], options={})
  if @busy
    ["busy..."]
  elsif connected?
    @socket.send("#{command}\n#{@invocation_id}\n#{params.join("\n")}", 0)
    result = nil
    @busy = true
    if options[:result_callback]
      @invocations[@invocation_id] = InvocationDescriptor.new(lambda do |r|
        @busy = false
        options[:result_callback].call(r)
      end)
      @invocation_id += 1
      ["pending..."]
    else
      @invocations[@invocation_id] = InvocationDescriptor.new(lambda do |r|
        result = r
        @busy = false
      end)
      @invocation_id += 1
      while !result
        sleep(0.1)
      end
      result
    end
  else
    connect unless connecting?
    ["connecting..."]
  end
end

def stop
  execute_command("stop")
  disconnect
end

private

def connected?
  @state == :connected && backend_running?
end

def connecting?
  @state == :connecting
end

def backend_running?
  if @process_id
    begin
      return true unless waitpid(@process_id, Process::WNOHANG)
    rescue Errno::ECHILD
    end
  end
  false
end

def disconnect
  @out_thread.join if @out_thread
  @sock_thread.kill if @sock_thread
  @socket.close if @socket rescue IOError
end

def tempfile_name
  dir = Dir.tmpdir
  i = 0
  file = nil 
  while !file || File.exist?(file)
    file = dir+"/rtext.temp.#{i}"
    i += 1
  end
  file
end

def connect
  disconnect
  @state = :connecting
  port = nil

  @logger.info @config.command

  out_file = tempfile_name 
  File.unlink(out_file) if File.exist?(out_file)

  Dir.chdir(File.dirname(@config.file)) do
    @process_id = spawn(@config.command.strip + " > #{out_file}")
  end

  @out_thread = Thread.new do
    @logger.info "out thread"
    output = ""
    while !File.exist?(out_file)
      sleep 0.1
    end
    while true
      output = File.read(out_file)
      if output =~ /^RText service, listening on port (\d+)/
        puts output
        port = $1.to_i
        break
      end
    end
    waitpid(@process_id)
    File.unlink(out_file)
  end

  @socket = UDPSocket.new

  @sock_thread = Thread.new do
    @logger.info "sock thread"
    while !port
      sleep(0.1)
    end
    @logger.info "connecting to #{port}"
    @socket.connect("127.0.0.1", port)
    @state = :connected
    while true
      begin
        data, from = @socket.recvfrom_nonblock(100000)
      rescue Errno::EWOULDBLOCK
        sleep(0.1)
        retry
      end
      #data = @socket.readpartial(100000)
      lines = data.split("\n")
      if lines.first =~ /^(\d+)$/
        inv_id = $1.to_i
        desc = @invocations[inv_id]
        if desc
          desc.result ||= []
          if lines[1] == "last"
            desc.proc.call(desc.result + lines[2..-1])
          else
            desc.result += lines[2..-1]
          end 
        else
          @logger.error "unknown answer"
        end
      else
        @logger.error "no invocation id"
      end
    end
  end
end

end

end

