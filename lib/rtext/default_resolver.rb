module RText

class DefaultResolver

def initialize(lang)
  @lang = lang
end

def resolve_fragment(fragment)
  @lang.reference_qualifier.call(fragment.unresolved_refs, fragment)
  fragment.resolve_local(
    :use_target_type => @lang.per_type_identifier)
end

def resolve_model(model)
  @lang.reference_qualifier.call(model.unresolved_refs, model)
  model.resolve(
    :fragment_provider => proc {|e|
        fr = @lang.fragment_ref(e)
        fr && fr.fragment
      }, 
    :use_target_type => @lang.per_type_identifier)
end

def find_targets(uref, model)
  @lang.reference_qualifier.call([uref], model)
  identifier = uref.proxy.targetIdentifier 
  targets = model.index[identifier]
  targets ||= []
  if @lang.per_type_identifier
    feature = @lang.feature_by_name(uref.element.class.ecore, uref.feature_name)
    if feature
      targets = targets.select{|t| t.is_a?(feature.eType.instanceClass)}
    end
  end 
  targets
end

end

end

