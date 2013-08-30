require 'json'

module RText

# this module provides an abstract JSON interface;
# it is a global configuration point for JSON conversion in RText;
# use +set_o2j_converter+ and +set_j2o_converter+ to use other json implementations
module JsonInterface

  # set the o2j converter, a proc which takes an object and returns json
  def self.set_o2j_converter(conv)
    define_method(:object_to_json, conv)
  end

  # set the j2o converter, a proc which takes json and returns an object
  def self.set_j2o_converter(conv)
    define_method(:json_to_object, conv)
  end

  def object_to_json(obj)
    JSON(obj)
  end

  def json_to_object(json)
    JSON(json)
  end

end

end

