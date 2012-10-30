require 'socket'
require 'rtext/completer'
require 'rtext/context_builder'
require 'rtext/message_helper'

module RText

class Service
  include RText::MessageHelper

  PortRangeStart = 9001
  PortRangeEnd   = 9100

  FlushInterval  = 1

  # Creates an RText backend service. Options:
  #
  #  :timeout
  #    idle time in seconds after which the service will terminate itelf
  #
  #  :logger
  #    a logger object on which the service will write its logging output
  #
  def initialize(lang, service_provider, options={})
    @lang = lang
    @service_provider = service_provider
    @completer = RText::Completer.new(lang) 
    @timeout = options[:timeout] || 60
    @logger = options[:logger]
  end

  def run
    server = create_server 
    puts "RText service, listening on port #{server.addr[1]}"
    $stdout.flush

    last_access_time = Time.now
    last_flush_time = Time.now
    @stop_requested = false
    sockets = []
    request_data = {}
    while !@stop_requested
      begin
        sock = server.accept_nonblock
        sockets << sock
        @logger.info "accepted connection" if @logger
      rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR, Errno::EWOULDBLOCK
      end
      sockets.dup.each do |sock|
        data = nil
        begin
          data = sock.read_nonblock(100000)
        rescue Errno::EWOULDBLOCK
        rescue EOFError
          request_data[sock] = nil
          sockets.delete(sock)
        end
        if data
          last_access_time = Time.now
          request_data[sock] ||= ""
          request_data[sock].concat(data)
          while obj = extract_message(request_data[sock])
            message_received(sock, obj)
          end
        end
      end
      IO.select([server] + sockets, [], [], 1)
      if Time.now > last_access_time + @timeout
        @logger.info("RText service, stopping now (timeout)") if @logger
        break 
      end
      if Time.now > last_flush_time + FlushInterval
        $stdout.flush
        last_flush_time = Time.now
      end
    end
  end

  def message_received(sock, obj)
    if check_request(obj) 
      response = { "type" => "response", "invocation_id" => obj["invocation_id"] }
      case obj["command"]
      when "load_model"
        load_model(sock, obj, response)
      when "content_complete"
        content_complete(sock, obj, response)
      when "link_targets" 
        link_targets(sock, obj, response)
      when "find_elements"
        find_elements(sock, obj, response)
      when "stop"
        @logger.info("RText service, stopping now (stop requested)") if @logger
        @stop_requested = true
      else
        @logger.warn("unknown command #{obj["command"]}") if @logger
        response["type"] = "unknown_command_error"
        response["command"] = obj["command"] 
      end
      sock.send(serialize_message(response), 0) if response
    end
  end

  private

  def check_request(obj)
    if obj["type"] != "request" 
      @logger.warn("received message is not a request") if @logger
      false
    elsif !obj["invocation_id"].is_a?(Integer)
      @logger.warn("invalid invocation id #{obj["invocation_id"]}") if @logger
      false
    else
      true
    end
  end

  def load_model(sock, request, response)
    progress_index = 0
    problems = @service_provider.get_problems(
      :on_progress => lambda do |frag, num_frags|
        progress_index += 1
        num_frags = 1 if num_frags < 1
        sock.send(serialize_message( {
          "type" => "progress",
          "invocation_id" => request["invocation_id"],
          "percentage" => progress_index*100/num_frags
        }), 0)
      end)
    total = 0
    response["problems"] = problems.collect do |fp|
      { "file" => fp.file,
        "problems" => fp.problems.collect do |p| 
            total += 1
            { "severity" => "error", "line" => p.line, "message" => p.message }
          end }
    end
    response["total_problems"] = total
  end

  def content_complete(sock, request, response)
    linepos = request["column"] 
    lines = request["context"]
    context = ContextBuilder.build_context(@lang, lines, linepos)
    @logger.debug("context element: #{@lang.identifier_provider.call(context.element, nil)}") \
      if context && @logger
    current_line = lines.last
    current_line ||= ""
    options = @completer.complete(context, lambda {|ref| 
        @service_provider.get_reference_completion_options(ref, context).collect {|o|
          Completer::CompletionOption.new(o.identifier, "<#{o.type}>")}
      })
    response["options"] = options.collect do |o|
      { "insert" => o.text, "display" => "#{o.text} #{o.extra}" }
    end
  end

  def link_targets(sock, request, response)
    linepos = request["column"] 
    lines = request["context"]
    current_line = lines.last
    context = ContextBuilder.build_context(@lang, lines, lines.last.size)
    if context && current_line[linepos..linepos] =~ /[\w\/]/
      ident_start = (current_line.rindex(/[^\w\/]/, linepos) || -1)+1
      ident_end = (current_line.index(/[^\w\/]/, linepos) || current_line.size)-1
      ident = current_line[ident_start..ident_end]
      response["begin_column"] = ident_start
      response["end_column"] = ident_end
      targets = []
      if current_line[0..linepos+1] =~ /^\s*\w+$/
        @service_provider.get_referencing_elements(ident, context).each do |t|
          targets << { "file" => t.file, "line" => t.line, "display" => t.display_name }
        end
      else
        @service_provider.get_reference_targets(ident, context).each do |t|
          targets << { "file" => t.file, "line" => t.line, "display" => t.display_name }
        end
      end
      response["targets"] = targets
    end
  end

  def find_elements(sock, request, response)
    pattern = request["search_pattern"] 
    total = 0
    response["elements"] = @service_provider.get_open_element_choices(pattern).collect do |c|
      total += 1
      { "display" => c.display_name, "file" => c.file, "line" => c.line }
    end
    response["total_elements"] = total
  end

  def create_server
    port = PortRangeStart
    begin
      # using the IP address implies IPv4
      serv = TCPServer.new("127.0.0.1", port)
    rescue Errno::EADDRINUSE, Errno::EAFNOSUPPORT
      port += 1
      retry if port <= PortRangeEnd
      raise
    end
    serv
  end

end

end

