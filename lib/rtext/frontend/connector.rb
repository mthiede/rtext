require 'socket'
require 'tmpdir'
require 'rtext/message_helper'

module RText
module Frontend

class Connector
include Process
include RText::MessageHelper

def initialize(config, options={})
  @config = config
  @logger = options[:logger]
  @state = :off
  @invocation_id = 1
  @invocations = {}
  @busy = false
  @connection_listener = options[:connect_callback]
end

def execute_command(obj, options={})
  if @busy
    do_work
    :backend_busy 
  elsif connected?
    obj["invocation_id"] = @invocation_id
    obj["type"] = "request"
    @socket.send(serialize_message(obj), 0)
    result = nil
    @busy = true
    if options[:response_callback]
      @invocations[@invocation_id] = lambda do |r|
        if r["type"] == "response" || r["type"] =~ /.*error$/
          @busy = false
        end
        options[:response_callback].call(r)
      end
      @invocation_id += 1
      do_work
      :request_pending 
    else
      @invocations[@invocation_id] = lambda do |r|
        if r["type"] == "response" || r["type"] == /.*error$/ 
          result = r
          @busy = false
        end
      end
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
    :connecting 
  end
end

def resume
  do_work
end

def stop
  execute_command({"type" => "request", "command" => "stop"})
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

  @logger.info @config.command if @logger

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
      port = $1.to_i
      @logger.info "connecting to #{port}" if @logger
      @socket = TCPSocket.new("127.0.0.1", port)
      @state = :connected
      @work_state = :read_from_socket
      @connection_listener.call if @connection_listener
    end
    true
  when :read_from_socket
    repeat = true
    socket_closed = false
    response_data = ""
    while repeat
      repeat = false
      data = nil
      begin
        data = @socket.read_nonblock(100000)
      rescue Errno::EWOULDBLOCK
      rescue EOFError
        socket_closed = true
        @logger.error "server socket closed (end of file)" if @logger
      end
      if data
        repeat = true
        response_data.concat(data)
        while obj = extract_message(response_data)
          inv_id = obj["invocation_id"] 
          callback = @invocations[inv_id]
          if callback
            callback.call(obj)
          else
            @logger.error "unknown answer" if @logger
          end
        end
        true
      elsif !backend_running? || socket_closed
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
end

