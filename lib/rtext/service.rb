require 'socket'
require 'rtext/completer'
require 'rtext/context_element_builder'

module RText

# =RText Backend Service
#
# RText editors consist of a frontend and a backend. Most of the logic is implemented
# within the backend while the frontend is kept as thin as possible. This should simplify
# the task of writing a frontend and promote development of RText frontends for different
# editing environments.
#
# Each instance of the backend service (i.e. operating system process) represents
# a model instantiated from RText files found at a specific location in the file system.
# The process should be kept running as long as editing is in process. This will greatly 
# reduce response times as the model can be kept in memory and only the changed parts need
# to be reloaded.
#
#
# ==Frontend/Backend Communication Protocol
#
# Communication takes place via plain text transmitted via UDP. There are requests by
# the frontend and responses by the backend. In both cases the text is interpreted as
# a set of lines (separated by \n or \r\n).
#
#
# ===Request
#
# The request consists of a command id, an invocation id and the command parameters.
# The invocation id is repeated within the response to allow proper association with the
# request. Command parameters are command specific (see below).
#
# Requests can not span more than one UDP package and thus are limited to the UDP payload size.
#
#  line 1:    <command id>
#  line 2:    <invocation id>
#  line 3..n: <command parameters>
#
#
# ===Response
#
# Each response contains the invocation id of the request in the first line.
# Since it could be splitted over several UDP packages it contains an indication 
# in the second line if more packages are following ("more") or this is the last package 
# ("last"). The rest of the response is a fragment of the command result data. All fragments
# of a set of response packages with the same invocation id need to be joined.
#
# Note that there are no mechanisms to protect agains package loss or reordering since
# this protocol is intended to be used on local socket connections only.
#
#  line 1:    <invocation id>
#  line 2:    "more" | "last"
#  line 3..n: <command result data>
#
#
# ===Command: Refresh
#
# The refresh command tells the backend to reload the model from the file system. Frontends
# could issue this command after a model file has been changed in the file system or on
# an explicit user request.
#
#  Request Format:
#    command id:          "refresh"
#    no parameters 
# 
#  Response Format:
#    no result data
#
# ===Command: Complete
#
# This command is a request by the frontend to show auto completion options at a given
# location within a file. The location is expressed using a set of context lines and the cursor
# column position in the current line.
#
# Context lines are lines from an RText file which contain a (context) command and all 
# the parent commands wrapped around it. Any sibling commands can be omitted as well as
# any lines containing closing braces and brackets. The order of lines is the same as in the RText file.
#
# Here is an example. Consider the following RText file with the cursor in the line of "Command3" at 
# the time when the auto completion command is issued.
#
#  Command1 {
#    Command2 {
#      role1: [
#        Command3          <== cursor in this line
#        Command4
#      ]
#    }
#    Command5
#  }
#
# The context lines in this case would be the following.
#
#  Command1 {
#    Command2 {
#      role1: [
#        Command3
#
# Note that all siblings of the command and parent commands have been stripped off, as well as
# any closing braces or brackets.
#
# The purpose of this special context line format is to keep the task of extracting the
# context in the frontend simple and the amount of data transmitted to the backend low.
# It's also a way to keep the parsing time of the context low in the backend and thus to minimize
# the user noticable delay.
#
#  Request Format:
#    command id:          "complete"
#    param line 1:        cursor column position in the current line 
#    param line 2..n:     context lines
#
#  Response Format:
#    result line 1..n:    <completion string>;<extra info string>
#
#
# ===Command: Show Problems
#
# This command is a request by the frontend to determine and return all problems present in the current model.
# The command implicitly reloads the model from the filesystem before checking for problems.
#
#  Request Format:
#    command id:          "show_problems"
#    no parameters 
#
#  Response Format:
#    result line n:       <file name>
#    result line n+1..n+m <line number>;<message>
#
# Note that the file name is repeated only once for all problems within a file to reduce the amout of
# result data which needs to be transmitted.
#    
#
# ===Command: Reference Targets
#
# This command is used to retrieve the targets of a given reference. The reference location is expressed
# by means of a set of context lines and the cursor column position in the current line. The cursor 
# column position must be within the string representing the reference. The format of the context lines
# is the same as the one described with the "Complete" command (see above).
#
# Note that the service provider is free to define how a reference is represented. In particular it
# can interpret the command identifier as a reference and use this mechanism to show incoming references
# (reverse references).
#
# As references can be ambiguous, the result is a list of possible targets. Each target consists of the
# filename and line number of the target element as well as the text to be displayed to the user in case
# there are more than one targets to choose from.
#
#  Request Format:
#    command id:          "get_reference_targets" 
#    param line 1:        cursor column position in the current line 
#    param line 2..n:     context lines
#
#  Response Format:
#    result line 1..n:    <file name>;<line number>;<display name>
#
#
# ===Command: Find Elements
# 
# This command returns a set of model elements matching a search pattern. The format of the
# pattern depends on the service provider. In a simple case, the pattern is the beginning of
# the element names.
#
#  Request Format:
#    command id:          "get_elements"
#    param line 1:        <seach pattern>
#
#  Response Format:
#    result line 1..n:    <display name>;<file name>;<line number>
# 
#
# ===Command: Stop
#
# This command is normally invoked when the frontend terminates or otherwise needs to terminate
# the backend service. When receiving this command, the backend will terminate.
#
#  Request Format:
#    command id:          "stop"
#    no parameters
#
#  Response Format:
#    no result data
#
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
      case cmd
      when "refresh"
        response = refresh(lines) 
      when "complete"
        response = complete(lines)
      when "show_problems"
        response = get_problems(lines)
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

  def send_response(response, invocation_id, socket, from)
    @logger.debug(response.inspect) if @logger
    loop do
      packet_lines = []
      size = 0
      while response.size > 0 && size + response.first.size < 65000
        size += response.first.size
        packet_lines << response.shift
      end
      if response.size > 0
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
    context = ContextElementBuilder.build_context_element(@lang, lines, linepos)
    @logger.debug("context element: #{@lang.identifier_provider.call(context, nil)}") if @logger
    current_line = lines.pop
    current_line ||= ""
    options = @completer.complete(current_line, linepos, 
      proc {|i| lines[-i]}, 
      proc {|ref| 
        @service_provider.get_reference_completion_options(ref, context).collect {|o|
          Completer::CompletionOption.new(o.identifier, "<#{o.type}>")}
      })
    options.collect { |o|
      "#{o.text};#{o.extra}\n"
    }
  end

  def get_problems(lines)
    # TODO: severity
    result = []
    @service_provider.get_problems.each do |fp|
      result << fp.file+"\n"
      fp.problems.each do |p| 
        result << "#{p.line};#{p.message}\n"
      end
    end
    result
  end

  def get_reference_targets(lines)
    linepos = lines.shift.to_i
    context = ContextElementBuilder.build_context_element(@lang, lines, linepos)
    current_line = lines.last
    result = []
    if current_line[linepos..linepos] =~ /[\w\/]/
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

