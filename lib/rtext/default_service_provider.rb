module RText

class DefaultServiceProvider

  def initialize(language, fragmented_model, model_loader, options={})
    @lang = language
    @model = fragmented_model
    @loader = model_loader 
    @element_name_index = nil
    @result_limit = options[:result_limit]
    @model.add_fragment_change_listener(proc {|fragment, kind|
      @element_name_index = nil
    })
  end

  def language
    @lang
  end

  def load_model(options={})
    if options[:on_progress]
      @loader.load(:on_progress => options[:on_progress])
    else
      @loader.load
    end
  end

  ReferenceCompletionOption = Struct.new(:identifier, :type)
  def get_reference_completion_options(reference, context)
    if @model.environment
      targets = @model.environment.find(:class => reference.eType.instanceClass)
    else
      clazz = reference.eType.instanceClass
      targets = @model.index.values.flatten.select{|e| e.is_a?(clazz)}
    end
    index = 0
    targets.collect{|t| 
      ident = @lang.identifier_provider.call(t, context.element, reference, index)
      index += 1
      if ident
        ReferenceCompletionOption.new(ident, t.class.ecore.name)
      else
        nil
      end
    }.compact.sort{|a,b| a.identifier <=> b.identifier}
  end

  ReferenceTarget = Struct.new(:file, :line, :display_name)
  def get_reference_targets(identifier, element, feature)
    result = []
    urefs = [ 
      RGen::Instantiator::ReferenceResolver::UnresolvedReference.new(element, feature.name,
        RGen::MetamodelBuilder::MMProxy.new(identifier)) ] 
    @lang.reference_qualifier.call(urefs, @model)
    identifier = urefs.first.proxy.targetIdentifier 
    targets = @model.index[identifier]
    if targets && @lang.per_type_identifier
      if feature
        targets = targets.select{|t| t.is_a?(feature.eType.instanceClass)}
      end
    end 
    targets && targets.each do |t|
      if @lang.fragment_ref(t)
        path = File.expand_path(@lang.fragment_ref(t).fragment.location)
        result << ReferenceTarget.new(path, @lang.line_number(t), "#{identifier} [#{t.class.ecore.name}]")
      end
    end
    result
  end

  def get_referencing_elements(identifier, element, feature)
    result = []
    targets = @model.index[@lang.identifier_provider.call(element, nil, nil, nil)]
    if targets && @lang.per_type_identifier
      targets = targets.select{|t| t.class == element.class}
    end
    if targets && targets.size == 1
      target = targets.first
      elements = target.class.ecore.eAllReferences.select{|r|
        r.eOpposite && !r.containment && !r.eOpposite.containment}.collect{|r|
          target.getGenericAsArray(r.name)}.flatten
      elements.each do |e|
        if @lang.fragment_ref(e)
          path = File.expand_path(@lang.fragment_ref(e).fragment.location)
          display_name = ""
          ident = @lang.identifier_provider.call(e, nil, nil, nil)
          display_name += "#{ident} " if ident
          display_name += "[#{e.class.ecore.name}]"
          result << ReferenceTarget.new(path, @lang.line_number(e), display_name)
        end
      end
    end
    result
  end

  FileProblems = Struct.new(:file, :problems)
  Problem = Struct.new(:severity, :line, :message)
  def get_problems(options={})
    load_model(options)
    result = []
    @model.fragments.sort{|a,b| a.location <=> b.location}.each do |fragment|
      problems = []
      if fragment.data && fragment.data[:problems]
        fragment.data[:problems].each do |p|
          problems << Problem.new("Error", p.line, p.message)
        end
      end
      fragment.unresolved_refs.each do |ur|
        # TODO: where do these proxies come from?
        next unless ur.proxy.targetIdentifier
        problems << Problem.new("Error", @lang.line_number(ur.element), "unresolved reference #{ur.proxy.targetIdentifier}")
      end
      if problems.size > 0
        result << FileProblems.new(File.expand_path(fragment.location), problems)
      end
    end
    result
  end

  OpenElementChoice = Struct.new(:display_name, :file, :line)
  def get_open_element_choices(pattern)
    result = []
    return result unless pattern
    sub_index = element_name_index[pattern[0..0].downcase]
    truncate_result = false
    sub_index && sub_index.each_pair do |ident, elements|
      if !truncate_result && ident.split(/\W/).last.downcase.index(pattern.downcase) == 0
        elements.each do |e|
          if @lang.fragment_ref(e)
            non_word_index = ident.rindex(/\W/)
            if non_word_index
              name = ident[non_word_index+1..-1]
              scope = ident[0..non_word_index-1]
            else
              name = ident
              scope = ""
            end
            display_name = "#{name} [#{e.class.ecore.name}]"
            display_name += " - #{scope}" if scope.size > 0
            path = File.expand_path(@lang.fragment_ref(e).fragment.location)
            if !@result_limit || result.size < @result_limit
              result << OpenElementChoice.new(display_name, path, @lang.line_number(e))
            else
              truncate_result = true
            end
          end
        end
      end
    end
    result = result.sort{|a,b| a.display_name <=> b.display_name}
    if truncate_result
      result << OpenElementChoice.new("--- result truncated, showing first #{@result_limit} entries ---", "/", 1)
    end
    result
  end

  def element_name_index
    return @element_name_index if @element_name_index
    @element_name_index = {}
    @model.index.each_pair do |ident, elements|
      last_part = ident.split(/\W/).last
      next unless last_part
      key = last_part[0..0].downcase
      @element_name_index[key] ||= {} 
      @element_name_index[key][ident] = elements
    end
    @element_name_index
  end

end

end
