require 'socket'
require 'tmpdir'
require 'rtext/message_helper'

module RText
module Frontend

class Connector
include Process
include RText::MessageHelper

ConnectTimeout = 10

def initialize(config, options={})
  @config = config
  @logger = options[:logger]
  @state = :off
  @invocation_id = 1
  @invocations = {}
  @busy = false
  @busy_start_time = nil
  @connection_listener = options[:connect_callback]
  @outfile_provider = options[:outfile_provider]
  @keep_outfile = options[:keep_outfile]
end

def execute_command(obj, options={})
  timeout = options[:timeout] || 5
  @busy = false if @busy_start_time && (Time.now > @busy_start_time + timeout)
  if @busy
    do_work
    :backend_busy 
  elsif connected?
    obj["invocation_id"] = @invocation_id
    obj["type"] = "request"
    @socket.send(serialize_message(obj), 0)
    result = nil
    @busy = true
    @busy_start_time = Time.now
    if options[:response_callback]
      @invocations[@invocation_id] = lambda do |r|
        if r["type"] == "response" || r["type"] =~ /error$/
          @busy = false
        end
        options[:response_callback].call(r)
      end
      @invocation_id += 1
      do_work
      :request_pending 
    else
      @invocations[@invocation_id] = lambda do |r|
        if r["type"] == "response" || r["type"] =~ /error$/ 
          result = r
          @busy = false
        end
      end
      @invocation_id += 1
      while !result
        if Time.now > @busy_start_time + timeout
          result = :timeout
          @busy = false
        else
          sleep(0.1)
          do_work
        end
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
  @connect_start_time = Time.now

  @logger.info @config.command if @logger

  if @outfile_provider
    @out_file = @outfile_provider.call
  else
    @out_file = tempfile_name 
  end
  File.unlink(@out_file) if File.exist?(@out_file)

  Dir.chdir(File.dirname(@config.file)) do
    @process_id = spawn(@config.command.strip + " > #{@out_file} 2>&1")
  end
  @work_state = :wait_for_file
end

def do_work
  case @work_state
  when :wait_for_file
    if File.exist?(@out_file)
      @work_state = :wait_for_port
    end
    if Time.now > @connect_start_time + ConnectTimeout
      cleanup
      @connection_listener.call(:timeout) if @connection_listener
      @work_state = :done
      @state = :off
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
      @connection_listener.call(:connected) if @connection_listener
    end
    if Time.now > @connect_start_time + ConnectTimeout
      cleanup
      @connection_listener.call(:timeout) if @connection_listener
      @work_state = :done
      @state = :off
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
      rescue IOError, EOFError, Errno::ECONNRESET
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
        cleanup
        @work_state = :done
        false
      end
    end
  end

end

def cleanup
  @socket.close if @socket
  File.unlink(@out_file) unless @keep_outfile
end

end

end
end

