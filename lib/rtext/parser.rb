require 'rtext/generic'
require 'rtext/tokenizer'

module RText 

class Parser
  include RText::Tokenizer

  Problem = Struct.new(:message, :line)

  def initialize(reference_regexp)
    @reference_regexp = reference_regexp
  end

  def parse(str, options)
    @dsc_visitor = options[:descent_visitor]
    @asc_visitor = options[:ascent_visitor]
    @problems = options[:problems] || []
    @non_consume_count = 0
    @consume_problem_reported = false
    @tokens = tokenize(str, @reference_regexp, :on_command_token => options[:on_command_token])
    @last_line = @tokens.last && @tokens.last.line 
    #@debug = true
    begin
      while next_token
        statement = parse_statement(true, true)
      end
    rescue InternalError
    end
  end

  # parse a statement with optional leading comment or an unassociated comment
  def parse_statement(is_root=false, allow_unassociated_comment=false)
    comments = [] 
    comment = parse_comment 
    annotation = parse_annotation
    if (next_token && next_token == :identifier) || !allow_unassociated_comment
      comments << [ comment, :above] if comment
      command = consume(:identifier)
      if command
        @dsc_visitor.call(command)
        arg_list = []
        parse_argument_list(arg_list)
        element_list = []
        if next_token == "{"
          parse_statement_block(element_list, comments)
        end
        eol_comment = parse_eol_comment
        comments << [ eol_comment, :eol ] if eol_comment
        consume(:newline)
        @asc_visitor.call(command, arg_list, element_list, comments, annotation, is_root)
      else
        discard_until(:newline)
        nil
      end
    elsif comment
      # if there is no statement, the comment is non-optional
      comments << [ comment, :unassociated ]
      @asc_visitor.call(nil, nil, nil, comments, nil, nil)
      nil
    else
      # die expecting an identifier (next token is not an identifier)
      consume(:identifier)
      discard_until(:newline)
      nil
    end
  end

  def parse_comment
    result = nil 
    while next_token == :comment
      result ||= []
      result << consume(:comment)
      consume(:newline)
    end
    result
  end

  def parse_annotation
    result = nil
    while next_token == :annotation
      result ||= []
      result << consume(:annotation)
      consume(:newline)
    end
    result
  end

  def parse_eol_comment
    if next_token == :comment
      consume(:comment)
    else
      nil
    end
  end

  def parse_statement_block(element_list, comments)
    consume("{")
    eol_comment = parse_eol_comment
    comments << [ eol_comment, :eol ] if eol_comment
    consume(:newline)
    while next_token && next_token != "}"
      parse_block_element(element_list, comments)
    end
    consume("}")
  end

  def parse_block_element(element_list, comments)
    if next_token == :label
      label = consume(:label)
      element_list << [label, parse_labeled_block_element(comments)]
    else
      statement = parse_statement(false, true)
      element_list << statement if statement 
    end
  end

  def parse_labeled_block_element(comments)
    if next_token == "["
      parse_element_list(comments)
    else
      eol_comment = parse_eol_comment
      comments << [ eol_comment, :eol ] if eol_comment
      nl = consume(:newline)
      discard_until(:newline) unless nl
      parse_statement
    end
  end

  def parse_element_list(comments)
    consume("[")
    eol_comment = parse_eol_comment
    comments << [ eol_comment, :eol ] if eol_comment
    nl = consume(:newline)
    discard_until(:newline) unless nl
    result = []
    while next_token && next_token != "]"
      statement = parse_statement(false, true)
      result << statement if statement 
    end
    consume("]")
    eol_comment = parse_eol_comment
    comments << [ eol_comment, :eol ] if eol_comment
    consume(:newline)
    result
  end

  def parse_argument_list(arg_list)
    first = true
    while (AnyValue + [",", "[", :label, :error]).include?(next_token)
      consume(",") unless first
      first = false
      parse_argument(arg_list)
    end
  end

  def parse_argument(arg_list)
    if next_token == :label
      label = consume(:label)
      arg_list << [label, parse_argument_value]
    else
      arg_list << parse_argument_value
    end
  end

  def parse_argument_value
    if next_token == "["
      parse_argument_value_list
    else
      parse_value
    end
  end

  def parse_argument_value_list
    consume("[")
    first = true
    result = []
    while (AnyValue + [",", :error]).include?(next_token)
      consume(",") unless first
      first = false
      result << parse_value
    end
    consume("]")
    result
  end

  AnyValue = [:identifier, :integer, :float, :string, :boolean, :reference, :generic] 

  def parse_value
    consume(*AnyValue)
  end

  def next_token
    @tokens.first && @tokens.first.kind
  end

  def discard_until(kind)
    t = @tokens.shift
    if t
      puts "discarding #{t.kind} #{t.value}" if @debug
      while t.kind != kind
        t = @tokens.shift
        break unless t
        puts "discarding #{t.kind} #{t.value}" if @debug
      end
    end
  end

  def consume(*args)
    t = @tokens.first
    if t.nil?
      @non_consume_count += 1
      report_consume_problem("Unexpected end of file, expected #{args.join(", ")}", @last_line)
      return nil
    end
    if args.include?(t.kind)
      @tokens.shift
      @consume_problem_reported = false
      @non_consume_count = 0
      puts "consuming #{t.kind} #{t.value}" if @debug
      t
    else
      if t.kind == :error
        @tokens.shift
        @non_consume_count = 0
        report_consume_problem("Parse error on token '#{t.value}'", t.line)
        return nil
      else
        value = " '#{t.value}'" if t.value
        @non_consume_count += 1
        report_consume_problem("Unexpected #{t.kind}#{value}, expected #{args.join(", ")}", t.line)
        return nil
      end
    end
  end

  class InternalError < Exception
  end

  def report_consume_problem(message, line)
    problem = Problem.new(message, line)
    if @non_consume_count > 100
      # safety check, stop reoccuring problems to avoid endless loops
      @problems << Problem.new("Internal error", line) 
      puts [@problems.last.message, @problems.last.line].inspect if @debug
      raise InternalError.new
    else
      if !@consume_problem_reported
        @consume_problem_reported = true
        @problems << problem 
        puts [@problems.last.message, @problems.last.line].inspect if @debug
      end
    end
  end

end

end

