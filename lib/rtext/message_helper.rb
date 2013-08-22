require 'json'

module RText

module MessageHelper

def serialize_message(obj)
  escape_all_strings(obj)
  json = object_to_json(obj)
  # the JSON method outputs data in UTF-8 encoding
  # the RText protocol expects message lengths measured in bytes
  # there shouldn't be any non-ascii-7-bit characters, though, so json.size would also be ok
  json.prepend(json.bytesize.to_s) 
  json
end

def extract_message(data)
  # interpret input data as binary
  data.force_encoding("binary")
  obj = nil
  if data =~ /^(\d+)\{/
    length_length = $1.size
    length = $1.to_i
    if data.size >= length_length + length
      data.slice!(0..(length_length-1))
      json = data.slice!(0..length-1)
      # there shouldn't be any non ascii-7-bit characters, transcode just to be sure
      # encode from binary to utf-8 with :undef => :replace turns all non-ascii-7-bit bytes
      # into the replacement character (\uFFFD)
      json.encode!("utf-8", :undef => :replace)
      obj = json_to_object(json)
    end
  end
  if obj
    unescape_all_strings(obj)
  end
  obj
end

# override this method to use other JSON implementations
def object_to_json(obj)
  JSON(obj)
end

# override this method to use other JSON implementations
def json_to_object(json)
  JSON(json)
end

def escape_all_strings(obj)
  each_json_object_string(obj) do |s|
    s.force_encoding("binary")
    bytes = s.bytes.to_a
    s.clear
    bytes.each do |b|
      if b >= 128 || b == 0x25 # %
        s << "%#{b.to_s(16)}".force_encoding("binary")
      else
        s << b.chr("binary")
      end
    end
    # there are no non ascii-7-bit characters left
    s.force_encoding("utf-8")
  end
end

def unescape_all_strings(obj)
  each_json_object_string(obj) do |s|
    # change encoding back to binary 
    # there could still be replacement characters (\uFFFD), turn them into "?"
    s.encode!("binary", :undef => :replace)
    s.gsub!(/%[0-9a-fA-F][0-9a-fA-F]/){|m| m[1..2].to_i(16).chr("binary")}
    s.force_encoding("binary")
  end
end

def each_json_object_string(object, &block)
  if object.is_a?(Hash)
    object.each_pair do |k, v|
      # don't call block for hash keys
      each_json_object_string(v, &block)
    end
  elsif object.is_a?(Array)
    object.each do |v|
      each_json_object_string(v, &block)
    end
  elsif object.is_a?(String)
    yield(object)
  else
    # ignore
  end
end

end

end
