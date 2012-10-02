require 'socket'
require 'rtext/completer'
require 'rtext/context_builder'

module RText

class Service
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
    socket = create_socket 
    puts "RText service, listening on port #{socket.addr[1]}"
    $stdout.flush

    last_access_time = Time.now
    last_flush_time = Time.now
    stop_requested = false
    while !stop_requested
      begin
        msg, from = socket.recvfrom_nonblock(65000)
      rescue Errno::EWOULDBLOCK
        sleep(0.01)
        if (Time.now - last_access_time) > @timeout
          @logger.info("RText service, stopping now (timeout)") if @logger
          break 
        end
        retry
      end
      if Time.now > last_flush_time + FlushInterval
        $stdout.flush
        last_flush_time = Time.now
      end
      last_access_time = Time.now
      lines = msg.split(/\r?\n/)
      cmd = lines.shift
      invocation_id = lines.shift
      response = nil
      progress_index = 0
      case cmd
      when "protocol_version"
        response = ["1"]
      when "refresh"
        response = refresh(lines) 
      when "complete"
        response = complete(lines)
      when "show_problems"
        response = get_problems(lines)
      when "show_problems2"
        response = get_problems(lines, :with_severity => true, :on_progress => lambda do |frag, num_frags|
          progress_index += 1
          num_frags = 1 if num_frags < 1
          progress = ["progress: #{progress_index*100/num_frags}"]
          send_response(progress, invocation_id, socket, from, :incremental => true)
        end)
      when "get_reference_targets"
        response = get_reference_targets(lines)
      when "get_elements"
        response = get_open_element_choices(lines)
      when "stop"
        response = [] 
        @logger.info("RText service, stopping now (stop requested)") if @logger
        stop_requested = true
      else
        @logger.debug("unknown command #{cmd}") if @logger
        response = []
      end
      send_response(response, invocation_id, socket, from)
    end
  end

  private

  def send_response(response, invocation_id, socket, from, options={})
    @logger.debug(response.inspect) if @logger
    loop do
      packet_lines = []
      size = 0
      while response.size > 0 && size + response.first.size < 65000
        size += response.first.size
        packet_lines << response.shift
      end
      if options[:incremental] || response.size > 0
        packet_lines.unshift("more\n")
      else
        packet_lines.unshift("last\n")
      end
      packet_lines.unshift("#{invocation_id}\n")
      socket.send(packet_lines.join, 0, from[2], from[1])
      break if response.size == 0 
    end
  end

  def create_socket
    socket = UDPSocket.new
    port = PortRangeStart
    begin
      socket.bind("localhost", port)
    rescue Errno::EADDRINUSE
      port += 1
      retry if port <= PortRangeEnd
      raise
    end
    socket
  end

  def refresh(lines)
    @service_provider.load_model
    []
  end

  def complete(lines)
    linepos = lines.shift.to_i
    context = ContextBuilder.build_context(@lang, lines, linepos)
    @logger.debug("context element: #{@lang.identifier_provider.call(context.element, nil)}") if context && @logger
    current_line = lines.pop
    current_line ||= ""
    options = @completer.complete(context, lambda {|ref| 
        @service_provider.get_reference_completion_options(ref, context).collect {|o|
          Completer::CompletionOption.new(o.identifier, "<#{o.type}>")}
      })
    options.collect { |o|
      "#{o.text};#{o.extra}\n"
    }
  end

  def get_problems(lines, options={})
    result = []
    severity = options[:with_severity] ? "e;" : ""
    @service_provider.get_problems(:on_progress => options[:on_progress]).each do |fp|
      result << fp.file+"\n"
      fp.problems.each do |p| 
        result << "#{severity}#{p.line};#{p.message}\n"
      end
    end
    result
  end

  def get_reference_targets(lines)
    linepos = lines.shift.to_i
    current_line = lines.last
    context = ContextBuilder.build_context(@lang, lines, lines.last.size)
    result = []
    if context && current_line[linepos..linepos] =~ /[\w\/]/
      ident_start = (current_line.rindex(/[^\w\/]/, linepos) || -1)+1
      ident_end = (current_line.index(/[^\w\/]/, linepos) || current_line.size)-1
      ident = current_line[ident_start..ident_end]
      result << "#{ident_start};#{ident_end}\n"
      if current_line[0..linepos+1] =~ /^\s*\w+$/
        @service_provider.get_referencing_elements(ident, context).each do |t|
          result << "#{t.file};#{t.line};#{t.display_name}\n"
        end
      else
        @service_provider.get_reference_targets(ident, context).each do |t|
          result << "#{t.file};#{t.line};#{t.display_name}\n"
        end
      end
    end
    result
  end

  def get_open_element_choices(lines)
    pattern = lines.shift
    @service_provider.get_open_element_choices(pattern).collect do |c|
      "#{c.display_name};#{c.file};#{c.line}\n"
    end
  end

end

end

