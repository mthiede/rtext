require 'rtext/instantiator'
require 'rtext/tokenizer'

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

  Context = Struct.new(:element, :feature, :prefix, :in_array, :in_block, :after_label, :problem)

  class << self
  include RText::Tokenizer

  # Builds the context information based on a set of +content_lines+. Content lines
  # are the RText lines containing the nested command headers in the original order.
  # The cursor is assumed to be in the last context line at column +position_in_line+
  def build_context(language, context_lines, position_in_line)
    context_info = fix_context(language, context_lines, position_in_line)
    return nil unless context_info
    element = instantiate_context_element(language, context_info)
    if element
      after_label = false
      if context_info.role
        if context_info.role.is_a?(Integer)
          feature = language.unlabled_arguments(element.class.ecore)[context_info.role] 
        else
          feature = element.class.ecore.eAllStructuralFeatures.find{|f| f.name == context_info.role}
          after_label = true
        end
      else
        feature = nil
      end
      Context.new(element, feature, context_info.prefix, context_info.in_array, context_info.in_block, after_label, context_info.problem)
    else
      Context.new(nil, nil, context_info.prefix, context_info.in_array, context_info.in_block, false, context_info.problem)
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
    if num_required_children == 0
      element
    elsif childs.size > 0
      find_leaf_child(childs.first, num_required_children-1)
    else
      nil
    end
  end

  ContextInternal = Struct.new(:lines, :num_elements, :role, :prefix, :in_array, :in_block, :problem)

  # extend +context_lines+ into a set of lines which can be processed by the RText
  def fix_context(language, context_lines, position_in_line)
    context_lines = context_lines.dup
    # make sure there is at least one line
    if context_lines.empty?
      context_lines << ""
    end
    position_in_line ||= context_lines.last.size
    # cut off last line right of cursor
    if position_in_line < 1
      context_lines.pop
      context_lines << ""
    else
      context_lines << context_lines.pop[0..position_in_line-1]
    end
    problem = nil
    line = context_lines.last
    if line =~ /\{\s*$/
      # remove curly brace from last line, required for correct counting of num_elements
      line.sub!(/\{\s*$/,"")
      problem = :after_curly
    end
    
    num_elements = in_block = in_array = missing_comma = role = prefix = nil
    tokens = tokenize(line, language.reference_regexp)
    tokens.pop if tokens.last && tokens.last.kind == :newline
    if tokens.size > 0 && tokens[0].kind == :identifier
      if tokens.size > 1 || line =~ /\s+$/
        # this line contains a new element
        num_elements = 1
        in_block = false
        in_array = false
        role = nil
        missing_comma = false
        unlabled_index = 0
        tokens[1..-1].each do |token|
          if token.kind == "["
            in_array = true
          elsif token.kind == "]"
            in_array = false
            missing_comma = true
            role = nil
          elsif token.kind == :label
            role = token.value.sub(/:$/, "")
          elsif token.kind == ","
            missing_comma = false
            role = nil unless in_array
            unlabled_index += 1 unless in_array
          end
        end
        if ((tokens.size == 1 && line =~ /\s+$/) || 
            tokens.last.kind == "," ||
            in_array ||
            ([:error, :string, :integer, :float, :boolean, :identifier, :reference].
              include?(tokens.last.kind) && line !~ /\s$/)) &&
            !tokens.any?{|t| t.kind == :label} &&
            !(problem == :after_curly)
          role ||= unlabled_index 
        end
        if [:string, :integer, :float, :boolean, :identifier, :reference].
            include?(tokens.last.kind) && line =~ /\s$/ && tokens.size > 1
            missing_comma = true
            role = nil unless in_array
        end
        if [:error, :string, :integer, :float, :boolean, :identifier, :reference].
            include?(tokens.last.kind) && line !~ /\s$/
          prefix = tokens.last.value.to_s
        else
          prefix = ""
        end
      else
        # in completion of command
        num_elements = 0
        missing_comma = false
        in_block = (context_lines.size > 1)
        prefix = tokens[0].value.to_s
        role, in_array = find_role(context_lines[0..-2])
        # fix single role lable
        if context_lines[-2] =~ /^\s*\w+:\s*$/
          context_lines[-1] = context_lines.pop
        end
      end
    elsif line.strip.empty?
      # in completion of command but without prefix
      num_elements = 0
      missing_comma = false
      in_block = (context_lines.size > 1)
      prefix = ""
      role, in_array = find_role(context_lines[0..-2])
      # fix single role lable
      if context_lines[-2] =~ /^\s*\w+:\s*$/
        context_lines[-1] = context_lines.pop
      end
    else
      # comment, closing brackets, etc.
      num_elements = 0
      missing_comma = false
      in_block = (context_lines.size > 1)
      return nil
    end

    # remove prefix, a value which is currently being completed should not be part of the
    # context model
    if prefix && prefix.size > 0
      line.slice!(-(prefix.size)..-1)
    end

    context_lines.reverse.each do |l|
      if l =~ /\{\s*$/
        context_lines << "}"
        num_elements += 1
      elsif l =~ /\[\s*$/
        context_lines << "]"
      end
    end
    problem = :missing_comma if !problem && missing_comma
    ContextInternal.new(context_lines, num_elements, role, prefix, in_array, in_block, problem)
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

