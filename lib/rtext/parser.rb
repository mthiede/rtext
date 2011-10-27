module RText 

class Parser

  def initialize(reference_regexp)
    @reference_regexp = reference_regexp
  end

  def parse(str, &visitor)
    @visitor = visitor
    @tokens = tokenize(str, @reference_regexp)
    @last_line = @tokens.last && @tokens.last.line 
    while next_token
      parse_statement(true, true)
    end
  end

  def parse_statement(is_root=false, allow_unassociated_comment=false)
    comments = [] 
    comment = parse_comment 
    if (next_token && next_token != "}" && next_token != "]") || !allow_unassociated_comment
      comments << [ comment, :above] if comment
      command = consume(:identifier)
      arg_list = []
      parse_argument_list(arg_list)
      element_list = []
      if next_token == "{"
        parse_statement_block(element_list, comments)
      end
      eol_comment = parse_eol_comment
      comments << [ eol_comment, :eol ] if eol_comment
      consume(:newline)
      @visitor.call(command, arg_list, element_list, comments, is_root)
    else
      comments << [ comment, :unassociated ] if comment
      @visitor.call(nil, nil, nil, comments, nil)
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
      consume(:newline)
      parse_statement
    end
  end

  def parse_element_list(comments)
    consume("[")
    eol_comment = parse_eol_comment
    comments << [ eol_comment, :eol ] if eol_comment
    consume(:newline)
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
    while !["{", :comment, :newline].include?(next_token)
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
    while next_token != "]"
      consume(",") unless first
      first = false
      result << parse_value
    end
    consume("]")
    result
  end

  def parse_value
    consume(:identifier, :integer, :float, :string, :boolean, :reference)
  end

  def next_token
    @tokens.first && @tokens.first.kind
  end

  class Error < Exception
    attr_reader :message, :line
    def initialize(message, line)
      @message, @line = message, line
    end
  end

  def consume(*args)
    t = @tokens.shift
    if t.nil?
      raise Error.new("Unexpected end of file, expected #{args.join(", ")}", @last_line)
    end
    if args.include?(t.kind)
      t
    else
      if t.kind == :error
        raise Error.new("Parse error on token '#{t.value}'", t.line)
      else
        value = " '#{t.value}'" if t.value
        raise Error.new("Unexpected #{t.kind}#{value}, expected #{args.join(", ")}", t.line)
      end
    end
  end

  Token = Struct.new(:kind, :value, :line)
   
  def tokenize(str, reference_regexp)
    result = []
    str.split(/\r?\n/).each_with_index do |str, idx|
      idx += 1
      if str =~ /^\s*#(.*)/
        result << Token.new(:comment, $1, idx) 
      else
        until str.empty?
          case str
          when reference_regexp
            str = $'
            result << Token.new(:reference, $&, idx)
          when /\A[-+]?\d+\.\d+(?:e[+-]\d+)?\b/
            str = $'
            result << Token.new(:float, $&.to_f, idx)
          when /\A0[xX][0-9a-fA-F]+\b/
            str = $'
            result << Token.new(:integer, $&.to_i(16), idx)
          when /\A[-+]?\d+\b/
            str = $'
            result << Token.new(:integer, $&.to_i, idx)
          when /\A"((?:[^"\\]|\\.)*)"/
            str = $'
            result << Token.new(:string, $1.
              gsub('\\\\','\\').
              gsub('\\"','"').
              gsub('\\n',"\n").
              gsub('\\r',"\r").
              gsub('\\t',"\t").
              gsub('\\f',"\f").
              gsub('\\b',"\b"), idx)
          when /\A(?:true|false)\b/
            str = $'
            result << Token.new(:boolean, $& == "true", idx)
          when /\A([a-zA-Z_]\w*)\b(?:\s*:)?/
            str = $'
            if $&[-1] == ?: 
              result << Token.new(:label, $1, idx)
            else
              result << Token.new(:identifier, $&, idx)
            end
          when /\A[\{\}\[\]:,]/
            str = $'
            result << Token.new($&, nil, idx)
          when /\A#(.*)/
            str = ""
            result << Token.new(:comment, $1, idx)
          when /\A\s+/
            str = $'
            # ignore
          when /\A\S+/
            str = $'
            result << Token.new(:error, $&, idx)
          end
        end
      end
      result << Token.new(:newline, nil, idx) \
        unless result.empty? || result.last.kind == :newline
    end
    result
  end

end

end

