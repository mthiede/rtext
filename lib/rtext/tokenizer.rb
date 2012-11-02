module RText

module Tokenizer

  Token = Struct.new(:kind, :value, :line)
   
  def tokenize(str, reference_regexp)
    result = []
    str.split(/\r?\n/).each_with_index do |str, idx|
      idx += 1
      if str =~ /^\s*([\#@])(.*)/
        if $1 == "#"
          result << Token.new(:comment, $2, idx) 
        else
          result << Token.new(:annotation, $2, idx) 
        end
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
          when /\A<([^>]*)>/
            str = $'
            result << Token.new(:generic, RText::Generic.new($1), idx)
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

