require 'rgen/ecore/ecore_ext'

module RText

class Completer

  CompletionOption = Struct.new(:text, :extra)

  # Creates a completer for RText::Language +language+.
  #
  def initialize(language)
    @lang = language
  end

  # Provides completion options
  #
  #  :ref_completion_option_provider
  #    a proc which receives a EReference and should return
  #    the possible completion options as CompletionOption objects 
  #    note, that the context element may be nil if this information is unavailable
  #
  def complete(context, ref_completion_option_provider=nil)
    clazz = context && context.element && context.element.class.ecore
    if clazz
      if context.in_block
        # command and lable completion within block
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
        types.uniq.select{|c| c.name.index(context.prefix) == 0}.
          sort{|a,b| a.name <=> b.name}.collect do |c| 
            class_completion_option(c)
          end +
        labled_refs.uniq.select{|r| r.name.index(context.prefix) == 0}.collect do |r|
            CompletionOption.new("#{r.name}:", "<#{r.eType.name}>")
          end
      elsif !context.problem
        result = []
        if context.feature
          if context.after_label
            description = "<#{context.feature.eType.name}>"
          else
            description = "[#{context.feature.name}] <#{context.feature.eType.name}>"
          end
          # value completion
          if context.feature.is_a?(RGen::ECore::EAttribute) || !context.feature.containment
            if context.feature.is_a?(RGen::ECore::EReference)
              if ref_completion_option_provider
                result += ref_completion_option_provider.call(context.feature).
                  select{|o| o.text.index(context.prefix) == 0}
              else
                # no options 
              end
            elsif context.feature.eType.is_a?(RGen::ECore::EEnum)
              result += context.feature.eType.eLiterals.select{|l| l.name.index(context.prefix) == 0}.collect do |l|
                CompletionOption.new("#{l.name}", "<#{context.feature.eType.name}>")
              end 
            elsif context.feature.eType.instanceClass == String && context.prefix == ""
              if @lang.unquoted?(context.feature)
                result += [ CompletionOption.new("#{context.feature.name.gsub(/\W/,"")}", description) ]
              else
                result += [ CompletionOption.new("\"\"", description) ]
              end
            elsif context.feature.eType.instanceClass == Integer 
              result += (0..0).select{|i| i.to_s.index(context.prefix) == 0}.collect{|i| CompletionOption.new("#{i}", description) }
            elsif context.feature.eType.instanceClass == Float 
              result += (0..0).select{|i| "#{i}.0".index(context.prefix) == 0}.collect{|i| CompletionOption.new("#{i}.0", description) }
            elsif context.feature.eType.instanceClass == RGen::MetamodelBuilder::DataTypes::Boolean
              result += [true, false].select{|b| b.to_s.index(context.prefix) == 0}.collect{|b| CompletionOption.new("#{b}", description) }
            else
              # no options 
            end
          else
            # containment reference, ignore
          end
        end
        if !context.after_label
          # label completion
          result += @lang.labled_arguments(clazz).
            select{|f| f.name.index(context.prefix) == 0 && 
              !context.element.eIsSet(f.name)}.collect do |f| 
              CompletionOption.new("#{f.name}:", "<#{f.eType.name}>")
            end 
        end
        result
      else
        # missing comma, after curly brace, etc.
        []
      end
    elsif context
      # root classes
      @lang.root_classes.select{|c| c.name.index(context.prefix) == 0}.
        sort{|a,b| a.name <=> b.name}.collect do |c| 
          class_completion_option(c)
        end 
    else
      []
    end
  end

  private

  def class_completion_option(eclass)
    uargs = @lang.unlabled_arguments(eclass).collect{|a| "<#{a.name}>"}.join(", ")
    CompletionOption.new(@lang.command_by_class(eclass.instanceClass), uargs)
  end

end

end

