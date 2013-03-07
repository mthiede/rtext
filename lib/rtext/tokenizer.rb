require 'rtext/generic'

module RText

module Tokenizer

  Token = Struct.new(:kind, :value, :line, :scol, :ecol)
   
  def tokenize(str, reference_regexp, options={})
    result = []
    on_command_token_proc = options[:on_command_token]
    str.split(/\r?\n/).each_with_index do |str, idx|
      idx += 1
      if idx == 1
        # remove UTF-8 BOM if present
        enc = str.encoding
        str.force_encoding("binary")
        str = str[3..-1] if str.index("\xEF\xBB\xBF".force_encoding("binary")) == 0
        str.force_encoding(enc)
      end
      if str =~ /^\s*([\#@])(.*)/
        if $1 == "#"
          result << Token.new(:comment, $2, idx, str.size-$2.size, str.size) 
        else
          result << Token.new(:annotation, $2, idx, str.size-$2.size, str.size) 
        end
      else
        col = 1
        first_token_in_line = true
        until str.empty?
          whitespace = false
          case str
          when reference_regexp
            str = $'
            result << Token.new(:reference, $&, idx, col, col+$&.size-1)
            col += $&.size
          when /\A[-+]?\d+\.\d+(?:e[+-]\d+)?\b/
            str = $'
            result << Token.new(:float, $&.to_f, idx, col, col+$&.size-1)
            col += $&.size
          when /\A0[xX][0-9a-fA-F]+\b/
            str = $'
            result << Token.new(:integer, $&.to_i(16), idx, col, col+$&.size-1)
            col += $&.size
          when /\A[-+]?\d+\b/
            str = $'
            result << Token.new(:integer, $&.to_i, idx, col, col+$&.size-1)
            col += $&.size
          when /\A"((?:[^"\\]|\\.)*)"/
            str = $'
            match = $&
            result << Token.new(:string, $1.
              gsub('\\\\','\\').
              gsub('\\"','"').
              gsub('\\n',"\n").
              gsub('\\r',"\r").
              gsub('\\t',"\t").
              gsub('\\f',"\f").
              gsub('\\b',"\b"), idx, col, col+match.size-1)
            col += match.size
          when /\A(?:true|false)\b/
            str = $'
            result << Token.new(:boolean, $& == "true", idx, col, col+$&.size-1)
            col += $&.size
          when /\A([a-zA-Z_]\w*)\b(?:\s*:)?/
            str = $'
            if $&[-1] == ?: 
              result << Token.new(:label, $1, idx, col, col+$&.size-1)
            else
              result << Token.new(:identifier, $&, idx, col, col+$&.size-1)
              if first_token_in_line && on_command_token_proc
                on_command_token_proc.call
              end
            end
            col += $&.size
          when /\A[\{\}\[\]:,]/
            str = $'
            result << Token.new($&, nil, idx, col, col+$&.size-1)
            col += $&.size
          when /\A#(.*)/
            str = ""
            result << Token.new(:comment, $1, idx, col, col+$&.size-1)
          when /\A\s+/
            str = $'
            col += $&.size
            whitespace = true
            # ignore
          when /\A<%((?:(?!%>).)*)%>/, /\A<([^>]*)>/
            str = $'
            result << Token.new(:generic, RText::Generic.new($1), idx, col, col+$&.size-1)
            col += $&.size
          when /\A\S+/
            str = $'
            result << Token.new(:error, $&, idx, col, col+$&.size-1)
            col += $&.size
          end
          first_token_in_line = false unless whitespace
        end
      end
      result << Token.new(:newline, nil, idx) \
        unless result.empty? || result.last.kind == :newline
    end
    result
  end

end

end

