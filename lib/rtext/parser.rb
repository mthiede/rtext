require 'rtext/generic'

module RText 

class Parser
  Problem = Struct.new(:message, :line)

  def parse(tokens, options)
    @dsc_visitor = options[:descent_visitor]
    @asc_visitor = options[:ascent_visitor]
    @problems = options[:problems] || []
    @non_consume_count = 0
    @consume_problem_reported = false
    @tokens = tokens
    @last_line = @tokens.last && @tokens.last.line 
    #@debug = true
    begin
      while next_token_kind
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
    if (next_token_kind && next_token_kind == :identifier) || !allow_unassociated_comment
      comments << [ comment, :above] if comment
      command = consume(:identifier)
      if command
        @dsc_visitor.call(command)
        arg_list = []
        parse_argument_list(arg_list)
        element_list = []
        if next_token_kind == "{"
          parse_statement_block(element_list, comments)
        end
        parse_eol_comment(comments)
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
    while next_token_kind == :comment
      result ||= []
      result << consume(:comment)
      consume(:newline)
    end
    result
  end

  def parse_annotation
    result = nil
    while next_token_kind == :annotation
      result ||= []
      result << consume(:annotation)
      consume(:newline)
    end
    result
  end

  def parse_eol_comment(comments)
    if next_token_kind == :comment
      comment = consume(:comment)
      comments << [comment, :eol]
    end
    nl = consume(:newline)
    discard_until(:newline) unless nl
  end

  def parse_statement_block(element_list, comments)
    consume("{")
    parse_eol_comment(comments)
    while next_token_kind && next_token_kind != "}"
      parse_block_element(element_list, comments)
    end
    consume("}")
  end

  def parse_block_element(element_list, comments)
    if next_token_kind == :label
      label = consume(:label)
      element_list << [label, parse_labeled_block_element(comments)]
    else
      statement = parse_statement(false, true)
      element_list << statement if statement 
    end
  end

  def parse_labeled_block_element(comments)
    if next_token_kind == "["
      parse_element_list(comments)
    else
      parse_eol_comment(comments)
      parse_statement
    end
  end

  def parse_element_list(comments)
    consume("[")
    parse_eol_comment(comments)
    result = []
    while next_token_kind && next_token_kind != "]"
      statement = parse_statement(false, true)
      result << statement if statement 
    end
    consume("]")
    parse_eol_comment(comments)
    result
  end

  def parse_argument_list(arg_list)
    first = true
    while (AnyValue + [",", "[", :label, :error]).include?(next_token_kind)
      unless first
        success = consume(",")
        consume(:newline) if success && next_token_kind == :newline
      end
      first = false
      parse_argument(arg_list)
    end
  end

  def parse_argument(arg_list)
    if next_token_kind == :label
      label = consume(:label)
      arg_list << [label, parse_argument_value]
    else
      arg_list << parse_argument_value
    end
  end

  def parse_argument_value
    if next_token_kind == "["
      parse_argument_value_list
    else
      parse_value
    end
  end

  def parse_argument_value_list
    consume("[")
    consume(:newline) if next_token_kind == :newline
    first = true
    result = []
    while (AnyValue + [",", :error]).include?(next_token_kind)
      unless first
        success = consume(",")
        consume(:newline) if success && next_token_kind == :newline
      end
      first = false
      result << parse_value
    end
    consume(:newline) if next_token_kind == :newline && next_token_kind(1) == "]"
    consume("]")
    result
  end

  AnyValue = [:identifier, :integer, :float, :string, :boolean, :reference, :generic] 

  def parse_value
    consume(*AnyValue)
  end

  def next_token_kind(idx=0)
    @tokens[idx] && @tokens[idx].kind
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

