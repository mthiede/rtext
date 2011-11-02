module RText

# ContextElementBuilder build a partial model from a set of context lines.
#
# Context lines are lines from an RText file which contain a (context) command and all 
# the parent commands wrapped around it. Any sibling commands can be omitted as well as
# any lines containing closing braces and brackets.
#
# The resulting partial model contains a (context) model element and all its parent
# elements. Further references are not resolved.
#
module ContextElementBuilder

  class << self

  # Instantiates the context element based on a set of +content_lines+. Content lines
  # are the RText lines containing the nested command headers in the original order.
  # The last line of +context_lines+ is the one which will create the context element.
  # +position_in_line+ is the cursor column position within the last line
  def build_context_element(language, context_lines, position_in_line)
    context_info = fix_context(context_lines)
    return nil unless context_info
    element = instantiate_context_element(language, context_info)
    unless element
      fix_current_line(context_info, position_in_line)
      element = instantiate_context_element(language, context_info)
    end
    element
  end

  private

  def instantiate_context_element(language, context_info)
    root_elements = []
    problems = []
    Instantiator.new(language).instantiate(context_info.lines.join("\n"),
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

  ContextInfo = Struct.new(:lines, :num_elements, :pos_leaf_element)

  # extend +context_lines+ into a set of lines which can be processed by the RText
  # instantiator: cut of curly brace from current line if present and add missing
  # closing curly braces and square brackets
  # returns a ContextInfo containing the new set of lines, the number of model elements
  # contained in this model snipped and the number of the line containing the leaf element
  def fix_context(context_lines)
    context_lines = context_lines.dup
    line = context_lines.last
    return nil if line.nil? || is_non_element_line(line)
    context_lines << strip_curly_brace(context_lines.pop)
    pos_leaf_element = context_lines.size-1
    num_elements = 1
    context_lines.reverse.each do |l|
      if l =~ /\{\s*$/
        context_lines << "}"
        num_elements += 1
      elsif l =~ /\[\s*$/
        context_lines << "]"
      end
    end
    ContextInfo.new(context_lines, num_elements, pos_leaf_element)
  end

  def is_non_element_line(line)
    line = line.strip
    line == "" || line == "}" || line == "]" || line =~ /^#/ || line =~ /^\w+:$/
  end

  def strip_curly_brace(line)
    line.sub(/\{\s*$/,'') 
  end

  def fix_current_line(context_info, pos_in_line)
    context_info.lines[context_info.pos_leaf_element] = 
      cut_current_argument(context_info.lines[context_info.pos_leaf_element], pos_in_line)
  end

  def cut_current_argument(line, pos_in_line)
    left_comma_pos = line.rindex(",", pos_in_line-1)
    if left_comma_pos
      line[0..left_comma_pos-1]
    elsif line =~ /^\s*\w+/
      $&
    else
      ""
    end
  end

  end

end

end

