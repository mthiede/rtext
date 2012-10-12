module RText

class Generic < RGen::MetamodelBuilder::MMGeneric
  attr_reader :string
  def initialize(string)
    @string = string
  end
end

end

