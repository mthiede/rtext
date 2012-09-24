require 'rtext/instantiator'

module RText

# The ContextBuilder builds context information for a set of context lines and the 
# cursor position in the current line. The context consists of 
#
# * the context element, i.e. the element surrounding the current cursor position,
#   the element is a new stand-alone element with all parent elements set up to the root,
#   all attributes and non-containment references before the cursor position will be set,
#   values right or below of the current cursor position will be ommitted,
#   the value directly left of the cursor with no space in between will also be ommitted,
#   (it is assumed that the value is currently being completed)
#   references are not being resolved
#
# * the current feature or nil if it can not be determined
#   if the cursor is inside or directly behind a role label, this label will be ignored
#   (it is assumed that the lable is currently being completed)
#
# * the completion prefix, this is the word directly left of the cursor
#
# * flag if cursor is in an array (i.e. within square brackets)
#
# * flag if the cursor is in the content block of the context element (i.e. within curly braces)
#
module ContextBuilder

  Context = Struct.new(:element, :feature, :prefix, :in_array, :in_block)

  class << self

  # Builds the context information based on a set of +content_lines+. Content lines
  # are the RText lines containing the nested command headers in the original order.
  # The cursor is assumed to be in the last context line at column +position_in_line+
  def build_context(language, context_lines, position_in_line)
    context_info = fix_context(context_lines, position_in_line)
    return nil unless context_info
    element = instantiate_context_element(language, context_info)
    if element
      feature = context_info.role &&
        element.class.ecore.eAllStructuralFeatures.find{|f| f.name == context_info.role}
      Context.new(element, feature, context_info.prefix, context_info.in_array, context_info.in_block)
    else
      Context.new(nil, nil, context_info.prefix, context_info.in_array, context_info.in_block)
    end
  end

  private

  def instantiate_context_element(language, context_info)
    root_elements = []
    problems = []
    text = context_info.lines.join("\n")
    Instantiator.new(language).instantiate(text,
      :root_elements => root_elements, :problems => problems)
    if root_elements.size > 0
      find_leaf_child(root_elements.first, context_info.num_elements-1)
    else
      nil
    end
  end

  def find_leaf_child(element, num_required_children)
    childs = element.class.ecore.eAllReferences.select{|r| r.containment}.collect{|r|
      element.getGenericAsArray(r.name)}.flatten
    if childs.size > 0
      find_leaf_child(childs.first, num_required_children-1)
    elsif num_required_children == 0
      element
    else
      nil
    end
  end

  ContextInternal = Struct.new(:lines, :num_elements, :role, :prefix, :in_array, :in_block)

  # extend +context_lines+ into a set of lines which can be processed by the RText
  def fix_context(context_lines, position_in_line)
    context_lines = context_lines.dup
    # make sure there is at least one line
    context_lines << "" if context_lines.empty?
    position_in_line ||= context_lines.last.size
    # cut off last line right of cursor
    context_lines << context_lines.pop[0..position_in_line-1]
    line = context_lines.last
    if line =~ /^\s*\w+\s+/
      # this line contains a new element
      num_elements = 1
      in_block = false
      # labled array value
      if line =~ /\W(\w+):\s*\[([^\]]*)$/
        role = $1
        array_content = $2
        in_array = true
        if array_content =~ /,\s*(\S*)$/
          prefix = $1
          line.sub!(/,\s*\S*$/, "]")
        else 
          array_content =~ /\s*(\S*)$/
          prefix = $1
          line.sub!(/\[[^\]]*$/, "[]")
        end
      # labled value
      elsif line =~ /\W(\w+):\s*(\S*)$/
        role = $1
        prefix = $2
        in_array = false
        line.sub!(/\s*\w+:\s*\S*$/, "")
        line.sub!(/,$/, "")
      # unlabled value or label
      elsif line =~ /[,\s](\S*)$/
        role = nil
        prefix = $1
        in_array = false
        line.sub!(/\s*\S*$/, "")
        line.sub!(/,$/, "")
      # TODO: unlabled array value
      else 
        # parse problem
        return nil
      end
    else
      # this line is in the content block
      num_elements = 0
      in_block = true
      # role or new element
      if line =~ /^\s*(\w*)$/
        prefix = $1
        role, in_array = find_role(context_lines[0..-2])
        # fix single role lable
        if context_lines[-2] =~ /^\s*\w+:\s*$/
          context_lines[-1] = context_lines.pop
        end
      else
        # comment, closing brackets, etc.
        return nil
      end
    end
    context_lines.reverse.each do |l|
      if l =~ /\{\s*$/
        context_lines << "}"
        num_elements += 1
      elsif l =~ /\[\s*$/
        context_lines << "]"
      end
    end
    ContextInternal.new(context_lines, num_elements, role, prefix, in_array, in_block)
  end

  def find_role(context_lines)
    block_nesting = 0
    array_nesting = 0
    non_empty_lines = 0
    context_lines.reverse.each do |line|
      # empty or comment
      next if line =~ /^\s*$/ || line =~ /^\s*#/
      # role
      if line =~ /^\s*(\w+):\s*$/
        return [$1, false] if non_empty_lines == 0
      # block open
      elsif line =~ /^\s*(\S+).*\{\s*$/
        block_nesting -= 1
        return [nil, false] if block_nesting < 0
      # block close
      elsif line =~ /^\s*\}\s*$/
        block_nesting += 1
      # array open
      elsif line =~ /^\s*(\w+):\s*\[\s*$/
        array_nesting -= 1
        return [$1, true] if array_nesting < 0
      # array close
      elsif line =~ /^\s*\]\s*$/
        array_nesting += 1
      end
      non_empty_lines += 1
    end
    [nil, false]
  end

  end

end

end

