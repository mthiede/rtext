require 'bigdecimal'
require 'rtext/language'
require 'rtext/generic'

module RText

class Serializer

  # Creates a serializer for RText::Language +language+.
  #
  def initialize(language)
    @lang = language
  end

  # Serialize +elements+ to +writer+. Options:
  #
  #  :set_line_number
  #    if set to true, the serializer will try to update the line number attribute of model
  #    elements, while they are serialized, given that they have the line_number_attribute
  #    specified in the RText::Language
  #    default: don't set line number
  #
  #  :fragment_ref
  #    an object referencing a fragment, this will be set on all model elements while they
  #    are serialized, given that they have the fragment_ref_attribute specified in the
  #    RText::Language
  #    default: don't set fragment reference
  #
  def serialize(elements, writer, options={})
    @writer = writer
    @set_line_number = options[:set_line_number]
    @fragment_ref = options[:fragment_ref]
    @line_number = 1
    @indent = 0
    if elements.is_a?(Array)
      serialize_elements(elements)
    else
      serialize_elements([elements])
    end
  end

  private

  def serialize_elements(elements)
    elements.each do |e|
      serialize_element(e)
    end
  end
  
  def serialize_element(element)
    # TODO: remove setting of fragment ref (doesn't belong into serializer)
    set_fragment_ref(element)
    set_line_number(element, @line_number) if @set_line_number
    clazz = element.class.ecore

    # the comment provider may modify the element
    comment = @lang.comment_provider && @lang.comment_provider.call(element)
    if comment
      comment.split(/\r?\n/).each do |l|
        write("##{l}")
      end
    end
    # the annotation provider may modify the element
    annotation = @lang.annotation_provider && @lang.annotation_provider.call(element)
    if annotation
      annotation.split(/\r?\n/).each do |l|
        write("@#{l}")
      end
    end
    headline = @lang.command_by_class(clazz.instanceClass)
    raise "no command name for class #{clazz.instanceClass.to_s}" unless headline
    args = []
    @lang.unlabled_arguments(clazz).each do |f|
      values = serialize_values(element, f)
      args << [f, values] if values
    end
    @lang.labled_arguments(clazz).each do |f|
      values = serialize_values(element, f)
      args << [f, "#{f.name}: #{values}"] if values
    end
    newline_arguments = false
    args.each_with_index do |arg, index|
      if @lang.newline_argument?(clazz, arg[0])
        headline += " \\" if index == 0
        headline += "\n" + @lang.indent_string * (@indent + 1)
        newline_arguments = true
      else
        headline += " "
      end
      headline += arg[1]
      headline += "," unless index == args.size-1
    end
    contained_elements = {}
    @lang.containments(clazz).each do |f|
      contained_elements[f] = element.getGenericAsArray(f.name) 
    end
    if contained_elements.values.any?{|v| v.size > 0}
      headline += " {"
      write(headline)
      iinc
      # additional indentation needed if there are arguments on separate lines;
      # note that this increment doesn't affect indentation of features of this element
      # that have array values, because they have already been formatted in serialize_values
      iinc if newline_arguments
      @lang.containments(clazz).each do |f|
        childs = contained_elements[f]
        if childs.size > 0
          child_classes = childs.collect{|c| c.class.ecore}.uniq
          if @lang.labeled_containment?(clazz, f) ||
              child_classes.any?{|c| @lang.containments_by_target_type(element.class.ecore, c).size > 1}
            if childs.size > 1
              write("#{f.name}: [")
              iinc
              serialize_elements(childs)
              idec
              write("]")
            else
              write("#{f.name}:")
              iinc
              serialize_elements(childs)
              idec
            end
          else
            serialize_elements(childs)
          end
        end
      end
      idec
      idec if newline_arguments
      write("}")
    else
      write(headline)
    end
  end

  def serialize_values(element, feature)
    values = element.getGenericAsArray(feature.name).compact
    result = []
    arg_format = @lang.argument_format(feature)
    values.each_with_index do |v, index|
      if v.is_a?(RText::Generic)
        str = v.string.split("%>").first
        if str.index(">")
          result << "<%#{str}%>"
        else
          result << "<#{str}>"
        end
      elsif feature.eType.instanceClass == Integer
        if arg_format 
          result << sprintf(arg_format, v)
        else
          result << v.to_s
        end
      elsif feature.eType.instanceClass == String
        if @lang.unquoted?(feature) && v.to_s =~ /^[a-zA-Z_]\w*$/m && v.to_s != "true" && v.to_s != "false"
          result << v.to_s
        else
          result << "\"#{v.gsub("\\","\\\\\\\\").gsub("\"","\\\"").gsub("\n","\\n").
            gsub("\r","\\r").gsub("\t","\\t").gsub("\f","\\f").gsub("\b","\\b")}\""
        end
      elsif feature.eType.instanceClass == RGen::MetamodelBuilder::DataTypes::Boolean
        result << v.to_s
      elsif feature.eType.instanceClass == Float
        if v.is_a?(BigDecimal)
          result << v.to_s("F")
          # formatting not available for BigDecimals
        else
          if arg_format 
          result << sprintf(arg_format, v)
          else
            result << v.to_s
          end
        end
      elsif feature.eType.is_a?(RGen::ECore::EEnum)
        if v.to_s =~ /^\d|\W/ || v.to_s == "true" || v.to_s == "false"
          result << "\"#{v.to_s.gsub("\\","\\\\\\\\").gsub("\"","\\\"").gsub("\n","\\n").
            gsub("\r","\\r").gsub("\t","\\t").gsub("\f","\\f").gsub("\b","\\b")}\""
        else
          result << v.to_s  
        end
      elsif feature.eType.instanceClass == Object
        if v.to_s =~ /^-?\d+(\.\d+)?$|^\w+$|^true$|^false$/
          result << v.to_s  
        else
          result << "\"#{v.to_s.gsub("\\","\\\\\\\\").gsub("\"","\\\"").gsub("\n","\\n").
            gsub("\r","\\r").gsub("\t","\\t").gsub("\f","\\f").gsub("\b","\\b")}\""
        end
      elsif feature.is_a?(RGen::ECore::EReference)
        result << @lang.identifier_provider.call(v, element, feature, index) 
      end
    end
    if result.size > 1
      if @lang.newline_array?(element.class.ecore, feature)
        # inside an array, indent two steps further than the command
        "[\n" + @lang.indent_string * (@indent + 2) +
          result.join(",\n" + @lang.indent_string * (@indent + 2)) +
          "\n" + @lang.indent_string * (@indent + 1) + "]"
      else
        "[#{result.join(", ")}]"
      end
    elsif result.size == 1
      result.first
    else
      nil
    end
  end

  def set_line_number(element, line)
    if @lang.line_number_attribute && element.respond_to?("#{@lang.line_number_attribute}=")
      element.send("#{@lang.line_number_attribute}=", line)
    end
  end

  def set_fragment_ref(element)
    if @fragment_ref && 
      @lang.fragment_ref_attribute && element.respond_to?("#{@lang.fragment_ref_attribute}=")
        element.send("#{@lang.fragment_ref_attribute}=", @fragment_ref)
    end
  end

  def write(str)
    @writer.write(@lang.indent_string * @indent + str + "\n")
    @line_number += 1
  end

  def iinc
    @indent += 1
  end

  def idec
    @indent -= 1
  end
end

end


