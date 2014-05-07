module RText
module Frontend

class Context

# lines: all lines from the beginning up to and including the current line
# pos: position of the cursor in the last lines
# returns the extracted lines and the new position in the last line
def extract(lines, pos)
  lines = filter_lines(lines)
  lines, new_pos = join_lines(lines, pos)
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
  [result, new_pos]
end

def filter_lines(lines)
  lines.reject { |l| 
    ls = l.strip
    ls[0..0] == "@" || ls[0..0] == "#"
  }
end

# when joining two lines, all whitespace after the last character of the first line is removed
# (after , and [); however whitespace at the end of the last of several joined lines is preserved;
# this way the context is correct even if the cursor is after the end of the last line 
# (i.e. with whitespace after the last non-whitespace character)
def join_lines(lines, pos)
  outlines = []
  while lines.size > 0
    outlines << lines.shift
    while lines.size > 0 && 
        (outlines.last =~ /,\s*$/ || 
        (outlines.last =~ /\[\s*$/ && outlines.last =~ /,/) ||
        (lines.first =~ /^\s*\]/ && outlines.last =~ /,/))
      outlines.last.rstrip!
      l = lines.shift
      if lines.size == 0
        # strip only left part, the prefix might have whitespace on the
        # right hand side which is relevant for the position
        non_ws_prefix = l[0..pos-1].lstrip
        pos = outlines.last.size + non_ws_prefix.size
      end
      outlines.last.concat(l.lstrip)
    end
  end
  [outlines, pos]
end

end

end
end

