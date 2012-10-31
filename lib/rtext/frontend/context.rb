module RText
module Frontend

module Context

# lines; all lines from the beginning up to and including the current line
def self.extract(lines)
  non_ignored_lines = 0
  array_nesting = 0
  block_nesting = 0
  last_element_line = 0
  result = []
  lines.reverse.each_with_index do |l, i|
    if i == 0
      result.unshift(l)
    else
      l = l.strip
      if l.size == 0 || l[0..0] == "#"
        # ignore empty lines and comments
      else
        non_ignored_lines += 1
        case l[-1..-1]
        when "{"
          if block_nesting > 0
            block_nesting -= 1 
          elsif block_nesting == 0
            result.unshift(l)
            last_element_line = non_ignored_lines
          end
        when "}"
          block_nesting += 1
        when "["
          if array_nesting > 0
            array_nesting -= 1
          elsif array_nesting == 0
            result.unshift(l)
          end
        when "]"
          array_nesting += 1
        when ":"
          # lable directly above element
          if non_ignored_lines == last_element_line + 1
            result.unshift(l)
          end
        end
      end
    end
  end
  result
end

end

end
end

