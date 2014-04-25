module RText
module Frontend

class Context

# lines; all lines from the beginning up to and including the current line
def extract(lines)
  lines = filter_lines(lines)
  lines, col_offset = join_lines(lines)
  non_ignored_lines = 0
  array_nesting = 0
  block_nesting = 0
  last_element_line = 0
  result = []
  lines.reverse.each_with_index do |l, i|
    if i == 0
      result.unshift(l)
    else
      non_ignored_lines += 1
      case l.strip[-1..-1]
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
  [result, col_offset]
end

def filter_lines(lines)
  lines.reject{|l| l.strip.empty? || l =~ /^[#@]/}
end

def join_lines(lines)
  outlines = []
  while lines.size > 0
    outlines << lines.shift
    last_col_offset = 0
    while lines.size > 0 && 
        (outlines.last =~ /,\s*$/ || 
        (outlines.last =~ /\[\s*$/ && outlines.last =~ /,/) ||
        (lines.first =~ /^\s*\]/ && outlines.last =~ /,/))
      l = lines.shift
      l =~ /^(\s*)/
      last_col_offset = outlines.last.size - $1.size
      outlines.last.concat(l.strip)
    end
  end
  [outlines, last_col_offset]
end

end

end
end

