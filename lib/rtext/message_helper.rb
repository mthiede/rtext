require 'json'

module RText

module MessageHelper

def serialize_message(obj)
  json = JSON(obj)
  "#{json.size}#{json}"
end

def extract_message(data)
  obj = nil
  if data =~ /^(\d+)\{/
    length_length = $1.size
    length = $1.to_i
    if data.size >= length_length + length
      data.slice!(0..(length_length-1))
      json = data.slice!(0..length-1)
      obj = JSON(json)
    end
  end
  obj
end

end

end
