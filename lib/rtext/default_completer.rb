require 'rgen/ecore/ecore_ext'

module RText

class DefaultCompleter

  CompletionOption = Struct.new(:text, :extra)

  # Creates a completer for RText::Language +language+.
  #
  def initialize(language)
    @lang = language
  end

  # Provides completion options
  #
  def complete(context)
    clazz = context && context.element && context.element.class.ecore
    if clazz
      if context.in_block
        block_options(context, clazz)
      elsif !context.problem
        result = []
        if context.feature
          add_value_options(context, result)
        end
        if !context.after_label
          add_label_options(context, clazz, result)
        end
        result
      else
        # missing comma, after curly brace, etc.
        []
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
        ([r.eType] + r.eType.eAllSubTypes).select{|t| !t.abstract}.each do |t|
          if @lang.containments_by_target_type(clazz, t).size > 1
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
        CompletionOption.new("#{r.name}:", "<#{r.eType.name}>")
      end
  end

  def add_value_options(context, result)
    if context.feature.is_a?(RGen::ECore::EAttribute) || !context.feature.containment
      if context.feature.is_a?(RGen::ECore::EReference)
        result.concat(reference_options(context))
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
      # containment reference, ignore
    end
  end

  def add_label_options(context, clazz, result)
    result.concat(@lang.labled_arguments(clazz).
      select{|f| 
        !context.element.eIsSet(f.name)}.collect do |f| 
        CompletionOption.new("#{f.name}:", "<#{f.eType.name}>")
      end )
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
      CompletionOption.new("#{lname}", "<#{context.feature.eType.name}>")
    end
  end

  def string_options(context)
    if @lang.unquoted?(context.feature)
      [ CompletionOption.new("#{context.feature.name.gsub(/\W/,"")}", value_description(context)) ]
    else
      [ CompletionOption.new("\"\"", value_description(context)) ]
    end
  end

  def integer_options(context)
    (0..0).collect{|i| CompletionOption.new("#{i}", value_description(context)) }
  end

  def float_options(context)
    (0..0).collect{|i| CompletionOption.new("#{i}.0", value_description(context)) }
  end

  def boolean_options(context)
    [true, false].collect{|b| CompletionOption.new("#{b}", value_description(context)) }
  end

  private

  def value_description(context)
    if context.after_label
      "<#{context.feature.eType.name}>"
    else
      "[#{context.feature.name}] <#{context.feature.eType.name}>"
    end
  end

  def class_completion_option(eclass)
    uargs = @lang.unlabled_arguments(eclass).collect{|a| "<#{a.name}>"}.join(", ")
    CompletionOption.new(@lang.command_by_class(eclass.instanceClass), uargs)
  end

end

end

