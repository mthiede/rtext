require 'socket'
require 'open3'
require 'tmpdir'

module RTextPlugin

class Connector
include Process

InvocationDescriptor = Struct.new(:received_proc, :update_proc, :result)

def initialize(config, logger, options={})
  @config = config
  @logger = logger
  @state = :off
  @invocation_id = 1
  @invocations = {}
  @busy = false
  @connection_listener = options[:on_connect]
end

def resume
  do_work
end

def execute_command(command, params=[], options={})
  if @busy
    do_work
    ["busy..."]
  elsif connected?
    @socket.send("#{command}\n#{@invocation_id}\n#{params.join("\n")}", 0)
    result = nil
    @busy = true
    if options[:result_callback]
      @invocations[@invocation_id] = InvocationDescriptor.new(lambda do |r|
        @busy = false
        options[:result_callback].call(r)
      end,
      lambda do |r|
        if options[:update_callback]
          options[:update_callback].call(r)
        end
      end)
      @invocation_id += 1
      do_work
      ["pending..."]
    else
      @invocations[@invocation_id] = InvocationDescriptor.new(lambda do |r|
        result = r
        @busy = false
      end,
      lambda do |r|
      end)
      @invocation_id += 1
      while !result
        sleep(0.1)
        do_work
      end
      result
    end
  else
    connect unless connecting?
    do_work
    ["connecting..."]
  end
end

def stop
  execute_command("stop")
  while do_work 
    sleep(0.1)
  end
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
  @state = :connecting

  @logger.info @config.command

  @out_file = tempfile_name 
  File.unlink(@out_file) if File.exist?(@out_file)

  Dir.chdir(File.dirname(@config.file)) do
    @process_id = spawn(@config.command.strip + " > #{@out_file}")
  end
  @work_state = :wait_for_file
end

def do_work
  case @work_state
  when :wait_for_file
    if File.exist?(@out_file)
      @work_state = :wait_for_port
    end
    true
  when :wait_for_port
    output = File.read(@out_file)
    if output =~ /^RText service, listening on port (\d+)/
      puts output
      port = $1.to_i
      @logger.info "connecting to #{port}"
      @socket = UDPSocket.new
      @socket.connect("127.0.0.1", port)
      @state = :connected
      @work_state = :read_from_socket
      @connection_listener.call if @connection_listener
    end
    true
  when :read_from_socket
    repeat = true
    while repeat
      repeat = false
      begin
        data, from = @socket.recvfrom_nonblock(100000)
      rescue Errno::EWOULDBLOCK
        data = nil
      end
      if data
        repeat = true
        lines = data.split("\n")
        if lines.first =~ /^(\d+)$/
          inv_id = $1.to_i
          desc = @invocations[inv_id]
          if desc
            desc.result ||= []
            if lines[1] == "last"
              desc.received_proc.call(desc.result + lines[2..-1])
            else
              desc.result += lines[2..-1]
              desc.update_proc.call(desc.result)
            end 
          else
            @logger.error "unknown answer"
          end
        else
          @logger.error "no invocation id"
        end
        true
      elsif !backend_running?
        @socket.close
        File.unlink(@out_file)
        @work_state = :done
        false
      end
    end
  end

end

end

end

