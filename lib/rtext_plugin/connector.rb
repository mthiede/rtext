require 'socket'
require 'open3'

module RTextPlugin

class Connector
include Process

InvocationDescriptor = Struct.new(:proc, :result)

def initialize(config)
  @config = config
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
  @out_thread.kill if @out_thread
  @sock_thread.kill if @sock_thread
  @socket.close if @socket rescue IOError
end

def connect
  disconnect
  @state = :connecting
  port = nil

  puts @config.command
  io_in = io_out = thread = nil
  Dir.chdir(File.dirname(@config.file)) do
    io_in, io_out, thread = Open3.popen2e(@config.command)
  end
  @process_id = thread.pid

  @out_thread = Thread.new do
    output = ""
    while true
      data = io_out.readpartial(100000)
      print "OUT:"+data
      if !port
        output.concat(data)
        if output =~ /^RText service, listening on port (\d+)/
          port = $1.to_i
        end
      end
    end
  end

  @socket = UDPSocket.new

  @sock_thread = Thread.new do
    while !port
      sleep(0.1)
    end
    puts "connecting to #{port}"
    @socket.connect("127.0.0.1", port)
    @state = :connected
    while true
      data = @socket.readpartial(100000)
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
          puts "WARN: unknown answer"
        end
      else
        puts "WARN: no invocation id"
      end
    end
  end
end

end

end

