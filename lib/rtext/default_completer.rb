require 'rgen/ecore/ecore_ext'

module RText

class DefaultCompleter

  class CompletionOption
    
    attr_accessor :insert
    attr_accessor :display
    attr_accessor :description

    def self.from_text_extra(text, extra)
      self.new(text, text + ' ' + extra)
    end
    
    def self.for_curly_braces(context)
      self.new("{\n#{context.line_indent}#{context.indent}||\n#{context.line_indent}}", '{}')
    end
    
    def self.for_square_brackets
      self.new('[ || ]', '[]', '')
    end
    
    def initialize(insert, display, description = nil)
      @insert = insert
      @display = display
      @description = description
    end
    
  end

  # Creates a completer for RText::Language +language+.
  #
  def initialize(language)
    @lang = language
  end

  # Provides completion options
  #
  def complete(context, version)
    clazz = context && context.element && context.element.class.ecore
    if clazz
      if context.position.in_block
        block_options(context, clazz)
      elsif !context.problem
        result = []
        add_value_options(context, result, version) if context.feature
        add_label_options(context, clazz, result, version) unless context.position.after_label
        result
      else
        # missing comma, after curly brace, etc.
        if version > 0 && !context.position.before_brace &&
            context.element.class.ecore.eAllReferences.any? { |r| r.containment }
          [CompletionOption.for_curly_braces(context)]
        else
          []
        end
      end
    elsif context
      root_options
    else
      []
    end
  end

  def block_options(context, clazz)
    types = []
    labled_refs = []
    if context.feature
      if context.feature.is_a?(RGen::ECore::EReference) && context.feature.containment
        types = @lang.concrete_types(context.feature.eType)
      else
        # invalid, ignore
      end
    else
      # all target types which don't need a label
      # and all lables which are needed by a potential target type
      @lang.containments(clazz).each do |r|
        ([r.eType] + r.eType.eAllSubTypes).select{|t| t.concrete}.each do |t|
          if @lang.labeled_containment?(clazz, r) || @lang.containments_by_target_type(clazz, t).size > 1
            labled_refs << r
          else
            types << t
          end
        end
      end
    end
    types.uniq.
      sort{|a,b| a.name <=> b.name}.collect do |c| 
        class_completion_option(c)
      end +
    labled_refs.uniq.collect do |r|
        CompletionOption.from_text_extra("#{r.name}:", "<#{r.eType.name}>")
      end
  end

  def add_value_options(context, result, version)
    if context.feature.is_a?(RGen::ECore::EAttribute) || !context.feature.containment
      if context.feature.is_a?(RGen::ECore::EReference)
        result.concat(reference_options(context))
        if version > 0 && !context.position.before_bracket && context.feature.upperBound != 1
          result << CompletionOption.for_square_brackets
        end
      elsif context.feature.eType.is_a?(RGen::ECore::EEnum)
        result.concat(enum_options(context))
      elsif context.feature.eType.instanceClass == String
        result.concat(string_options(context))
      elsif context.feature.eType.instanceClass == Integer 
        result.concat(integer_options(context))
      elsif context.feature.eType.instanceClass == Float 
        result.concat(float_options(context))
      elsif context.feature.eType.instanceClass == RGen::MetamodelBuilder::DataTypes::Boolean
        result.concat(boolean_options(context))
      else
        # no options 
      end
    else
      if version > 0 && !context.position.before_bracket && context.feature.upperBound != 1
        result << CompletionOption.for_square_brackets
      end
    end
  end

  def add_label_options(context, clazz, result, version)
    result.concat(@lang.labled_arguments(clazz).
      select{|f| 
        !context.element.eIsSet(f.name)}.collect do |f| 
        CompletionOption.from_text_extra("#{f.name}:", "<#{f.eType.name}>")
    end )
    if version > 0 && !context.position.after_comma &&
        context.element.class.ecore.eAllReferences.any? { |r| r.containment } && !context.position.before_brace
      result << CompletionOption.for_curly_braces(context)
    end
  end

  def root_options
    @lang.root_classes.
      sort{|a,b| a.name <=> b.name}.collect do |c| 
        class_completion_option(c)
      end 
  end

  def reference_options(context)
    []
  end

  def enum_options(context)
    context.feature.eType.eLiterals.collect do |l|
      lname = l.name
      if lname =~ /^\d|\W/ || lname == "true" || lname == "false"
        lname =  "\"#{lname.gsub("\\","\\\\\\\\").gsub("\"","\\\"").gsub("\n","\\n").
          gsub("\r","\\r").gsub("\t","\\t").gsub("\f","\\f").gsub("\b","\\b")}\""
      end
      CompletionOption.from_text_extra("#{lname}", "<#{context.feature.eType.name}>")
    end
  end

  def string_options(context)
    if @lang.unquoted?(context.feature)
      [ CompletionOption.from_text_extra("#{context.feature.name.gsub(/\W/,"")}", value_description(context)) ]
    else
      [ CompletionOption.from_text_extra("\"\"", value_description(context)) ]
    end
  end

  def get_default_value_completion(context)
    return nil unless context.feature.defaultValue
    CompletionOption.from_text_extra("#{context.feature.defaultValue}", value_description(context))
  end

  def integer_options(context)
    default_comp = get_default_value_completion(context)
    return [default_comp] if default_comp
    (0..0).collect{|i| CompletionOption.from_text_extra("#{i}", value_description(context)) }
  end

  def float_options(context)
    default_comp = get_default_value_completion(context)
    return [default_comp] if default_comp
    (0..0).collect{|i| CompletionOption.from_text_extra("#{i}.0", value_description(context)) }
  end

  def boolean_options(context)
    [true, false].collect{|b| CompletionOption.from_text_extra("#{b}", value_description(context)) }
  end

  private

  def value_description(context)
    if context.position.after_label
      "<#{context.feature.eType.name}>"
    else
      "[#{context.feature.name}] <#{context.feature.eType.name}>"
    end
  end

  def class_completion_option(eclass)
    uargs = @lang.unlabled_arguments(eclass).collect{|a| "<#{a.name}>"}.join(", ")
    CompletionOption.from_text_extra(@lang.command_by_class(eclass.instanceClass), uargs)
  end

end

end

