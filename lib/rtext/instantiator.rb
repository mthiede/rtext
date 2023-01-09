require 'rgen/ecore/ecore_ext'
require 'rgen/instantiator/reference_resolver'
require 'rtext/tokenizer'
require 'rtext/parser'

module RText

class Instantiator
  include RText::Tokenizer

  # A problem found during instantiation
  # if the file is not known, it will be nil
  InstantiatorProblem = Struct.new(:message, :file, :line)

  # Creates an instantiator for RText::Language +language+ 
  #
  def initialize(language)
    @lang = language
  end

  # instantiate +str+, +options+ include:
  #
  #  :env
  #    environment to which model elements will be added
  #
  #  :problems
  #    an array to which problems will be appended
  #  
  #  :unresolved_refs
  #    an array to which unresolved references will be appended
  # 
  #  :root_elements
  #    an array which will hold the root elements
  #
  #  :file_name
  #    name of the file being instantiated, will be set on model elements
  #
  #  :fragment_ref
  #    object which references the fragment being instantiated, will be set on model elements 
  #
  #  :on_progress
  #    a proc which is called with a number measuring the progress made since the last call;
  #    progress is measured by the number of command tokens recognized plus the number of
  #    model elements instantiated.
  #
  def instantiate(str, options={})
    @line_numbers = {}
    @env = options[:env]
    @problems = options[:problems] || []
    @unresolved_refs = options[:unresolved_refs]
    @root_elements = options[:root_elements] || []
    @file_name = options[:file_name]
    @fragment_ref = options[:fragment_ref]
    @on_progress_proc = options[:on_progress]
    @context_class_stack = []
    parser = Parser.new
    @root_elements.clear
    parser_problems = []
    tokens = tokenize(str, @lang.reference_regexp, 
      :on_command_token => @on_progress_proc && lambda do
        @on_progress_proc.call(1)
      end)
    parser.parse(tokens, 
      :descent_visitor => lambda do |command|
        clazz = @lang.class_by_command(command.value, @context_class_stack.last)
        # in case no class is found, nil will be pushed, this will case the next command
        # lookup to act as if called from toplevel
        @context_class_stack.push(clazz)
      end,
      :ascent_visitor => lambda do |*args|
        if args[0]
          element =create_element(*args)
          @context_class_stack.pop
          element
        else
          unassociated_comments(args[3])
        end
      end,
      :problems => parser_problems)
    parser_problems.each do |p|
      problem(p.message, p.line)
    end
  end

  private

  def unassociated_comments(comments)
    comments.each do |c|
      handle_comment(c, nil)
    end
  end

  def create_element(command, arg_list, element_list, comments, annotation, is_root)
    clazz = @context_class_stack.last 
    @on_progress_proc.call(1) if @on_progress_proc
    if !@lang.has_command(command.value)
      problem("Unknown command '#{command.value}'", command.line)
      return
    elsif !clazz 
      if is_root
        problem("Command '#{command.value}' can not be used on root level", command.line)
        return
      else
        problem("Command '#{command.value}' can not be used in this context", command.line)
        return
      end
    end
    if clazz.ecore.abstract
      problem("Unknown command '#{command.value}' (metaclass is abstract)", command.line)
      return
    end
    element = clazz.new
    @env << element if @env
    @root_elements << element if is_root
    unlabeled_args = @lang.unlabled_arguments(clazz.ecore).name
    di_index = 0
    defined_args = {}
    arg_list.each do |a|
      if is_labeled(a) 
        set_argument(element, a[0].value, a[1], defined_args, command.line)
      else
        if di_index < unlabeled_args.size
          set_argument(element, unlabeled_args[di_index], a, defined_args, command.line)
          di_index += 1
        elsif a != nil
          problem("Unexpected unlabeled argument, #{unlabeled_args.size} unlabeled arguments expected", command.line)
        end
      end
    end
    element_list.each do |e|
      if is_labeled(e)
        add_children(element, e[1], e[0].value, e[0].line)
      else
        add_children(element, e, nil, nil)
      end
    end
    set_line_number(element, command.line)
    set_file_name(element)
    set_fragment_ref(element)
    comments.each do |c|
      handle_comment(c, element)
    end
    handle_annotation(annotation, element) if annotation
    element
  end

  def add_children(element, children, role, role_line)
    if role
      feature = @lang.feature_by_name(element.class.ecore, role)
      if !feature
        problem("Unknown child role '#{role}'", role_line)
        return
      end
      if !feature.is_a?(RGen::ECore::EReference) || !feature.containment
        problem("Role '#{role}' can not take child elements", role_line)
        return
      end
      children = [children] unless children.is_a?(Array)
      children.compact!
      if children.size == 0
        return
      end
      if !feature.many && 
        (element.getGenericAsArray(role).size > 0 || children.size > 1)
        if children.size == 1
          # other child was created under another role lable with same name
          problem("Only one child allowed in role '#{role}'", line_number(children[0]))
        else
          problem("Only one child allowed in role '#{role}'", line_number(children[1]))
        end
        return
      end
      expected_type = nil
      children.each do |c|
        begin
          element.setOrAddGeneric(feature.name, c)
        rescue StandardError
          expected_type ||= @lang.concrete_types(feature.eType)
          problem("Role '#{role}' can not take a #{c.class.ecore.name}, expected #{expected_type.name.join(", ")}", line_number(c))
        end
      end
    else
      raise "if there is no role, children must not be an Array" if children.is_a?(Array)
      child = children
      return if child.nil?
      feature = @lang.containments_by_target_type(element.class.ecore, child.class.ecore)
      if feature.size == 0
        # this should never happen since the scope of an element is already checked when it's created
        problem("This kind of element can not be contained here", line_number(child))
        return
      end
      if feature.size > 1
        problem("Role of element is ambiguous, use a role label", line_number(child))
        return
      end
      feature = feature[0]
      if element.getGenericAsArray(feature.name).size > 0 && !feature.many
        problem("Only one child allowed in role '#{feature.name}'", line_number(child))
        return
      end
      element.setOrAddGeneric(feature.name, child)
    end
  end

  def set_argument(element, name, value, defined_args, line)
    feature = @lang.feature_by_name(element.class.ecore, name)
    if !feature
      problem("Unknown argument '#{name}'", line)
      return
    end
    if feature.is_a?(RGen::ECore::EReference) && feature.containment
      problem("Argument '#{name}' can only take child elements", line)
      return
    end
    if defined_args[name]
      problem("Argument '#{name}' already defined", line)
      return
    end
    value = [value] unless value.is_a?(Array)
    value.compact!
    if value.size > 1 && !feature.many
      problem("Argument '#{name}' can take only one value", line)
      return
    end
    expected_kind = expected_token_kind(feature)
    value.each do |v|
      if v.kind == :generic
        if @lang.generics_enabled
          element.setOrAddGeneric(feature.name, v.value)
        else
          problem("Generic value not allowed", line)
        end
      elsif !expected_kind.include?(v.kind)
        problem("Argument '#{name}' can not take a #{v.kind}, expected #{expected_kind.join(", ")}", line)
      elsif feature.eType.is_a?(RGen::ECore::EEnum) 
        if !feature.eType.eLiterals.name.include?(v.value)
          problem("Argument '#{name}' can not take value #{v.value}, expected #{feature.eType.eLiterals.name.join(", ")}", line)
        else
          element.setOrAddGeneric(feature.name, v.value.to_sym)
        end
      elsif feature.is_a?(RGen::ECore::EReference)
        proxy = RGen::MetamodelBuilder::MMProxy.new(v.value)
        if @unresolved_refs
          @unresolved_refs << 
            RGen::Instantiator::ReferenceResolver::UnresolvedReference.new(element, feature.name, proxy)
        end
        element.setOrAddGeneric(feature.name, proxy)
      else
        begin
          v_value = v.value
          feature_instance_class = feature.eType.instanceClass
          if feature_instance_class == String && (v_value.is_a?(Float) || v_value.is_a?(Fixnum))
            element.setOrAddGeneric(feature.name, v_value.to_s)
          elsif feature_instance_class == Float && v_value.is_a?(Fixnum)
            element.setOrAddGeneric(feature.name, v_value.to_f)
          else
            element.setOrAddGeneric(feature.name, v_value)
          end
        rescue StandardError
          # backward compatibility for RGen versions not supporting BigDecimal
          if v.value.is_a?(BigDecimal)
            element.setOrAddGeneric(feature.name, v.value.to_f)
          else
            raise
          end
        end
      end
    end
    defined_args[name] = true
  end

  def handle_comment(comment_desc, element)
    if @lang.comment_handler
      kind = comment_desc[1]
      if kind == :eol
        comment = comment_desc[0].value
      else
        comment = comment_desc[0].collect{|c| c.value}.join("\n")
      end
      success = @lang.comment_handler.call(comment, kind, element, @env)
      if !success 
        if element.nil? 
          problem("Unassociated comment not allowed", comment_desc[0][0].line)
        else
          problem("This kind of element can not take this comment", line_number(element))
        end
      end
    end
  end

  def handle_annotation(annotation_desc, element)
    if @lang.annotation_handler
      annotation = annotation_desc.collect{|c| c.value}.join("\n")
      success = @lang.annotation_handler.call(annotation, element, @env)
      if !success 
        problem("Annotation not allowed", line_number(element))
      end
    else
      problem("Annotation not allowed", line_number(element))
    end
  end

  def is_labeled(a)
    a.is_a?(Array) && a[0].respond_to?(:kind) && a[0].kind == :label
  end

  def expected_token_kind(feature)
    if feature.is_a?(RGen::ECore::EReference)
      [:reference, :identifier]
    elsif feature.eType.is_a?(RGen::ECore::EEnum)
      [:identifier, :string]
    else
      expected = { String => [:string, :identifier, :integer, :float],
        Integer => [:integer],
        Float => [:float, :integer],
        RGen::MetamodelBuilder::DataTypes::Boolean => [:boolean],
        Object => [:string, :identifier, :integer, :float, :boolean]
      }[feature.eType.instanceClass] 
      raise "unsupported EType instance class: #{feature.eType.instanceClass}" unless expected
      expected
    end
  end

  def set_line_number(element, line)
    @line_numbers[element] = line
    if @lang.line_number_attribute && element.respond_to?("#{@lang.line_number_attribute}=")
      element.send("#{@lang.line_number_attribute}=", line)
    end
  end

  def set_file_name(element)
    if @file_name && 
      @lang.file_name_attribute && element.respond_to?("#{@lang.file_name_attribute}=")
        element.send("#{@lang.file_name_attribute}=", @file_name)
    end
  end

  def set_fragment_ref(element)
    if @fragment_ref && 
      @lang.fragment_ref_attribute && element.respond_to?("#{@lang.fragment_ref_attribute}=")
        element.send("#{@lang.fragment_ref_attribute}=", @fragment_ref)
    end
  end

  def line_number(e)
    @line_numbers[e]
  end

  def problem(msg, line)
    @problems << InstantiatorProblem.new(msg, @file_name, line) 
  end

end

end

