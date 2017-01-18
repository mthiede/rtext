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
  @busy_start_time = nil
  @connection_listener = options[:connect_callback]
  @outfile_provider = options[:outfile_provider]
  @keep_outfile = options[:keep_outfile]
  @connection_timeout = options[:connection_timeout] || 10
  @process_id = nil
end

def execute_command(obj, options={})
  timeout = options[:timeout] || 10
  @busy = false if @busy_start_time && (Time.now > @busy_start_time + timeout)
  if @busy
    do_work
    return :backend_busy 
  end
  unless connected?
    connect unless connecting?
    do_work
  end
  if connected?
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
    :connecting
  end
end

def resume
  do_work
end

def stop
  while connecting?
    do_work
    sleep(0.1)
  end
  if connected?
    execute_command({"type" => "request", "command" => "stop"})
    while do_work 
      sleep(0.1)
    end
  end
  ensure_process_cleanup(@process_id, @keep_outfile ? nil : @out_file, 10)
  @process_id = nil
end

private

def wait_for_process_to_exit(process_id, timeout)
  with_timeout timeout do
    begin
      waitpid(process_id, Process::WNOHANG)
      process_id = nil
      true
    rescue Errno::ECHILD => _
      false
    end
  end
end

def ensure_process_cleanup(process_id, out_file, timeout)
  Thread.new do
    begin
      unless process_id.nil?
        process_id = nil if wait_for_process_to_exit(process_id, timeout)
      end
    ensure
      unless process_id.nil?
        begin
          Process.kill('QUIT', process_id)
        rescue Errno::ESRCH => _
        end
      end
      File.unlink(out_file) if !out_file.nil? && File.exist?(out_file)
    end
  end
end

def with_timeout(timeout, sleep_time = 0.1, &block)
  started = Time.now
  while true do
    return true if block.call
    if Time.now > started + timeout
      return false
    end
    sleep(sleep_time)
  end
end


def connected?
  !@process_id.nil? && @state == :read_from_socket && backend_running?
end

def connecting?
  !@process_id.nil? && (@state == :wait_for_file || @state == :wait_for_port)
end

def backend_running?
  if @process_id
    begin
      waitpid(@process_id, Process::WNOHANG)
      return true
    rescue Errno::ECHILD => _
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
  return if connected?
  @connect_start_time = Time.now

  @logger.info @config.command if @logger

  if @outfile_provider
    @out_file = @outfile_provider.call
  else
    @out_file = tempfile_name 
  end

  if @process_id.nil?
    File.unlink(@out_file) if File.exist?(@out_file)
    Dir.chdir(File.dirname(@config.file)) do
      @process_id = spawn(@config.command.strip + " > #{@out_file} 2>&1")
      @state = :wait_for_file
    end
  end
end

def do_work
  if @process_id.nil?
    @state = :off
    return false
  end
  if @state == :wait_for_port && !File.exist?(@out_file)
    @state = :wait_for_file
  end
  if @state == :wait_for_file && File.exist?(@out_file)
    @state = :wait_for_port
  end
  if @state == :wait_for_file
    while true
      if Time.now > @connect_start_time + @connection_timeout
        cleanup
        @connection_listener.call(:timeout) if @connection_listener
        @state = :off
        @logger.warn "process didn't startup (connection timeout)" if @logger
        return false
      end
      sleep(0.1)
      if File.exist?(@out_file)
        @state = :wait_for_port
        break
      end
    end
  end
  if @state == :wait_for_port
    while true
      break unless File.exist?(@out_file)
      output = File.read(@out_file)
      if output =~ /^RText service, listening on port (\d+)/
        port = $1.to_i
        @logger.info "connecting to #{port}" if @logger
        begin
          @socket = TCPSocket.new("127.0.0.1", port)
          @socket.setsockopt(:SOCKET, :RCVBUF, 1000000)
        rescue Errno::ECONNREFUSED
          cleanup
          @connection_listener.call(:timeout) if @connection_listener
          @state = :off
          @logger.warn "could not connect socket (connection timeout)" if @logger
          return false
        end
        @state = :read_from_socket
        @connection_listener.call(:connected) if @connection_listener
        break
      end
      if Time.now > @connect_start_time + @connection_timeout
        cleanup
        @connection_listener.call(:timeout) if @connection_listener
        @state = :off
        @logger.warn "could not connect socket (connection timeout)" if @logger
        return false
      end
      sleep(0.1)
    end
  end
  if @state == :read_from_socket
    repeat = true
    socket_closed = false
    response_data = ""
    while repeat
      repeat = false
      data = nil
      begin
        data = @socket.read_nonblock(1000000)
      rescue Errno::EWOULDBLOCK
      rescue IOError, EOFError, Errno::ECONNRESET
        socket_closed = true
        @logger.info "server socket closed (end of file)" if @logger
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
      elsif !backend_running? || socket_closed
        cleanup
        @state = :off
        return false
      end
    end
  end
  true
end

def cleanup
  @socket.close if @socket
  # wait up to 2 seconds for backend to shutdown
  for i in 0..20 
    break unless backend_running?
    sleep(0.1)
  end
  ensure_process_cleanup(@process_id, @keep_outfile ? @out_file : nil, 10)
end

end

end
end

