require 'rgen/ecore/ecore'
require 'rgen/ecore/ecore_ext'
require 'rgen/serializer/opposite_reference_filter'
require 'rgen/serializer/qualified_name_provider'

module RText

class Language
  
  # Creates an RText language description for the metamodel described by +root_epackage+
  # Valid options include:
  #
  #  :feature_provider
  #     a Proc which receives an EClass and should return a subset of this EClass's features
  #     this can be used to filter and/or reorder the features
  #     note that in most cases, this Proc will have to filter opposite references
  #     default: all features filtered using OppositeReferenceFilter 
  #
  #  :unlabled_arguments
  #     a Proc which receives an EClass and should return this EClass's feature names which are
  #     to be serialized without lables in the given order and before all labled arguments
  #     the features must also occur in :feature_provider if :feature_provider is provided
  #     if unlabled arguments are not part of the current class's features, they will be ignored
  #     default: no unlabled arguments
  #
  #  :unquoted_arguments
  #     a Proc which receives an EClass and should return this EClass's string typed attribute
  #     names which are to be serialized without quotes. input data my still be quoted.
  #     the serializer will take care to insert quotes if the data is not a valid identifier
  #     the features must also occur in :feature_provider if :feature_provider is provided
  #     default: no unquoted arguments
  #
  #  :labeled_containments
  #     a Proc which receives an EClass and should return this EClass's containment references
  #     which are to be serialized with a lable
  #     default: use lables when references can't be uniquely derived from contained element
  #  
  #  :argument_format_provider
  #     a Proc which receives an EAttribute and should return a format specification string
  #     (in sprintf syntax) which will be used by the serializer for integers and floats.
  #     default: if not present or the proc returns nil, then #to_s is used
  #
  #  :reference_regexp  
  #     a Regexp which is used by the tokenizer for identifying references 
  #     it must only match at the beginning of a string, i.e. it should start with \A
  #     it must be built in a way that does not match other language constructs
  #     in particular it must not match identifiers (word characters not starting with a digit)
  #     identifiers can always be used where references are expected
  #     default: word characters separated by at least one slash (/) 
  #
  #  :identifier_provider
  #     a Proc which receives an element, its containing element, the feature through which the
  #     element is referenced and the index position of the reference within the feature's values.
  #     the latter 3 argumnets may be nil. it should return the element's identifier as a string.
  #     the identifier must be unique for the element unless "per_type_identifier" is set to true,
  #     in which case they must be unique for each element of the same type.
  #     identifiers may be relative to the given containing element, depending on the given
  #     feature and index position. in this case a globally unique 
  #     identifier must be resonstructed by the proc specified using the :reference_qualifier option.
  #     if the containing element is nil, the identifier returned must be globally unique.
  #     default: identifiers calculated by QualifiedNameProvider
  #              in this case options to QualifiedNameProvider may be provided and will be passed through
  #
  #  :per_type_identifier
  #     if set to true, identifiers may be reused for elements of different type
  #     default: false
  #
  #  :reference_qualifier
  #     a Proc which receives RGen unresolved references and either a FragmentedModel or a ModelFragment.
  #     it should modify the unresolved references' targetIdentifiers to make them globally unique.
  #     the Proc is called for each fragment after it as been loaded and for the overall model.
  #     this can be used to qualify context specific references returned by the identifier provider.
  #     default: no reference qualifier
  #
  #  :root_classes
  #     an Array of EClass objects representing classes which can be used on root level
  #     default: all classes which can't be contained by any class
  #
  #  :line_number_attribute
  #     the name of the attribute which will be used to associate the line number with a model element
  #     default: no line number
  #
  #  :file_name_attribute
  #     the name of the attribute which will be used to associate the file name with a model element
  #     default: no file name
  #
  #  :fragment_ref_attribute
  #     the name of the attribute which will be used to associate a model fragment with a model element
  #
  #  :comment_handler 
  #     a Proc which will be invoked when a new element has been instantiated. receives  
  #     the comment as a string, the comment kind (one of [:above, :eol, :unassociated]), the
  #     element and the environment to which the element has been added to.
  #     the environment may be nil.  it should add the comment to the element and 
  #     return true. if the element can take no comment, it should return false.
  #     default: no handling of comments 
  #  
  #  :comment_provider
  #     a Proc which receives an element and should return this element's comment as a string or nil
  #     the Proc may also modify the element to remove information already part of the comment
  #     default: no comments
  #
  #  :annotation_handler
  #     a Proc which will be invoked when a new element has been instantiated. receives  
  #     the annotation as a string, the element and the environment to which the element has been added to.
  #     the environment may be nil. it may change the model or otherwise use the annotated information. 
  #     if the element can take no annotation, it should return false, otherwise true.
  #     default: no handling of annotations 
  #
  #  :annotation_provider
  #     a Proc which receives an element and should return this element's annotation as a string or nil.
  #     the Proc may also modify the element to remove information already part of the annotation.
  #     default: no annotations
  #
  #  :indent_string
  #     the string representing one indent, could be a tab or spaces
  #     default: 2 spaces
  #
  #  :command_name_provider
  #     a Proc which receives an EClass object and should return an RText command name
  #     default: class name
  #
  #  :backward_ref_attribute
  #     a Proc which receives an EClass object and should return the name of this class's
  #     feature which is used to represent backward references (i.e. for following the backward
  #     reference, the user must click on a value of this attribute)
  #     a value of nil means that the command name is used to follow the backward reference
  #     default: nil (command name)
  #  
  #  :enable_generics
  #     if set to true, generics (<value>) are allowed, otherwise forbidden
  #     default: false
  #
  def initialize(root_epackage, options={})
    @root_epackage = root_epackage
    @feature_provider = options[:feature_provider] || 
      proc { |c| RGen::Serializer::OppositeReferenceFilter.call(c.eAllStructuralFeatures).
        reject{|f| f.derived} }
    @unlabled_arguments = options[:unlabled_arguments]
    @unquoted_arguments = options[:unquoted_arguments]
    @labeled_containments = options[:labeled_containments]
    @argument_format_provider = options[:argument_format_provider]
    @root_classes = options[:root_classes] || default_root_classes(root_epackage)
    command_name_provider = options[:command_name_provider] || proc{|c| c.name}
    setup_commands(root_epackage, command_name_provider)
    @reference_regexp = options[:reference_regexp] || /\A\w*(\/\w*)+/
    @identifier_provider = options[:identifier_provider] || 
      proc { |element, context, feature, index|
        @qualified_name_provider ||= RGen::Serializer::QualifiedNameProvider.new(options)
        name_attribute = options[:attribute_name] || "name"
        if element.is_a?(RGen::MetamodelBuilder::MMProxy) || element.respond_to?(name_attribute)
          @qualified_name_provider.identifier(element)
        else
          nil
        end
      }
    @reference_qualifier = options[:reference_qualifier] || proc{|urefs, model_or_fragment| }
    @line_number_attribute = options[:line_number_attribute]
    @file_name_attribute = options[:file_name_attribute]
    @fragment_ref_attribute = options[:fragment_ref_attribute]
    @comment_handler = options[:comment_handler]
    @comment_provider = options[:comment_provider]
    @annotation_handler = options[:annotation_handler]
    @annotation_provider = options[:annotation_provider]
    @indent_string = options[:indent_string] || "  "
    @per_type_identifier = options[:per_type_identifier]
    @backward_ref_attribute = options[:backward_ref_attribute] || proc{|c| nil}
    @generics_enabled = options[:enable_generics]
  end

  attr_reader :root_epackage
  attr_reader :root_classes
  attr_reader :reference_regexp
  attr_reader :identifier_provider
  attr_reader :reference_qualifier
  attr_reader :line_number_attribute
  attr_reader :file_name_attribute
  attr_reader :fragment_ref_attribute
  attr_reader :comment_handler
  attr_reader :comment_provider
  attr_reader :annotation_handler
  attr_reader :annotation_provider
  attr_reader :indent_string
  attr_reader :per_type_identifier
  attr_reader :backward_ref_attribute
  attr_reader :generics_enabled

  def class_by_command(command, context_class)
    map = @class_by_command[context_class]
    map && map[command]
  end

  def has_command(command)
    @has_command[command]
  end

  def command_by_class(clazz)
    @command_by_class[clazz]
  end

  def containments(clazz)
    features(clazz).select{|f| f.is_a?(RGen::ECore::EReference) && f.containment}
  end

  def non_containments(clazz)
    features(clazz).reject{|f| f.is_a?(RGen::ECore::EReference) && f.containment}
  end

  def labled_arguments(clazz)
    non_containments(clazz) - unlabled_arguments(clazz)
  end

  def unlabled_arguments(clazz)
    return [] unless @unlabled_arguments
    uargs = @unlabled_arguments.call(clazz) || []
    uargs.collect{|a| non_containments(clazz).find{|f| f.name == a}}.compact
  end

  def unquoted?(feature)
    return false unless @unquoted_arguments
    @unquoted_arguments.call(feature.eContainingClass).include?(feature.name)
  end

  def labeled_containment?(clazz, feature)
    return false unless @labeled_containments
    @labeled_containments.call(clazz).include?(feature.name)
  end

  def argument_format(feature)
    @argument_format_provider && @argument_format_provider.call(feature)
  end

  def concrete_types(clazz)
    ([clazz] + clazz.eAllSubTypes).select{|c| !c.abstract}
  end

  def containments_by_target_type(clazz, type)
    map = {}
    containments(clazz).each do |r|
      concrete_types(r.eType).each {|t| (map[t] ||= []) << r}
    end
    ([type]+type.eAllSuperTypes).inject([]){|m,t| m + (map[t] || []) }.uniq
  end

  def feature_by_name(clazz, name)
    clazz.eAllStructuralFeatures.find{|f| f.name == name}
  end

  def file_name(element)
    @file_name_attribute && element.respond_to?(@file_name_attribute) && element.send(@file_name_attribute)
  end

  def line_number(element)
    @line_number_attribute && element.respond_to?(@line_number_attribute) && element.send(@line_number_attribute)
  end

  def fragment_ref(element)
    @fragment_ref_attribute && element.respond_to?(@fragment_ref_attribute) && element.send(@fragment_ref_attribute)
  end

  private

  def setup_commands(root_epackage, command_name_provider)
    @class_by_command = {}
    @command_by_class = {}
    @has_command = {}
    root_epackage.eAllClasses.each do |c|
      next if c.abstract
      cmd = command_name_provider.call(c)
      @command_by_class[c.instanceClass] = cmd 
      @has_command[cmd] = true
      clazz = c.instanceClass
      @class_by_command[clazz] ||= {} 
      containments(c).collect{|r|
          [r.eType] + r.eType.eAllSubTypes}.flatten.uniq.each do |t|
        next if t.abstract
        cmw = command_name_provider.call(t)
        raise "ambiguous command name #{cmw}" if @class_by_command[clazz][cmw]
        @class_by_command[clazz][cmw] = t.instanceClass
      end
    end
    @class_by_command[nil] = {} 
    @root_classes.each do |c|
      next if c.abstract
      cmw = command_name_provider.call(c)
      raise "ambiguous command name #{cmw}" if @class_by_command[nil][cmw]
      @class_by_command[nil][cmw] = c.instanceClass
    end
  end

  def default_root_classes(root_package)
    root_epackage.eAllClasses.select{|c| !c.abstract &&
      !c.eAllReferences.any?{|r| r.eOpposite && r.eOpposite.containment}}
  end

  def features(clazz)
    @feature_provider.call(clazz)
  end

  # caching
  [ :features,
    :containments,
    :non_containments,
    :unlabled_arguments,
    :labled_arguments,
    :unquoted?,
    :labeled_containment?,
    :argument_format,
    :concrete_types,
    :containments_by_target_type,
    :feature_by_name
  ].each do |m|
    ms = m.to_s.sub('?','_')
    module_eval <<-END
      alias #{ms}_orig #{m}
      def #{m}(*args)
        @#{ms}_cache ||= {}
        return @#{ms}_cache[args] if @#{ms}_cache.has_key?(args)
        @#{ms}_cache[args] = #{ms}_orig(*args)
      end
    END
  end

end

end

