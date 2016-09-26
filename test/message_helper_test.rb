$:.unshift File.join(File.dirname(__FILE__),"..","lib")

gem 'minitest'
require 'minitest/autorun'
require 'rtext/message_helper'

class MessageHelperTest < MiniTest::Test
include RText::MessageHelper

def test_serialize
  str = serialize_message({"key" => 1})
  assert_equal '9{"key":1}', str
  str = serialize_message({"key" => true})
  assert_equal '12{"key":true}', str
  str = serialize_message({"key" => "value"})
  assert_equal '15{"key":"value"}', str
  str = serialize_message({"key" => {"nested" => "value"}})
  assert_equal '26{"key":{"nested":"value"}}', str
  str = serialize_message({"key" => ["value1", "value2"]})
  assert_equal '27{"key":["value1","value2"]}', str

  # a iso-8859-1 'ä' 
  str = serialize_message({"key" => "umlaut\xe4".force_encoding("binary")})
  assert_equal '19{"key":"umlaut%e4"}', str
  str = serialize_message({"key" => "umlaut\xe4".force_encoding("iso-8859-1")})
  assert_equal '19{"key":"umlaut%e4"}', str
  str = serialize_message({"key" => "umlaut\xe4".force_encoding("cp850")})
  assert_equal '19{"key":"umlaut%e4"}', str
  str = serialize_message({"key" => "umlaut\xe4".force_encoding("utf-8")})
  assert_equal '19{"key":"umlaut%e4"}', str

  # a utf-8 'ä'
  str = serialize_message({"key" => "umlaut\xc3\xa4".force_encoding("binary")})
  assert_equal '22{"key":"umlaut%c3%a4"}', str
  str = serialize_message({"key" => "umlaut\xc3\xa4".force_encoding("iso-8859-1")})
  assert_equal '22{"key":"umlaut%c3%a4"}', str
  str = serialize_message({"key" => "umlaut\xc3\xa4".force_encoding("cp850")})
  assert_equal '22{"key":"umlaut%c3%a4"}', str
  str = serialize_message({"key" => "umlaut\xc3\xa4".force_encoding("utf-8")})
  assert_equal '22{"key":"umlaut%c3%a4"}', str

  # %
  str = serialize_message({"key" => "%"})
  assert_equal '13{"key":"%25"}', str
end

def test_extract
  # specified length too short
  assert_raises JSON::ParserError do
    extract_message('8{"key":1}')
  end
  # specified length too long
  assert_raises JSON::ParserError do
    extract_message('10{"key":1}x')
  end
  # message data shorter than length specifie, waits for more data
  extract_message('10{"key":1}')

  obj = extract_message('9{"key":1}')
  assert_equal({"key" => 1}, obj)
  obj = extract_message('12{"key":true}')
  assert_equal({"key" => true}, obj)
  obj = extract_message('15{"key":"value"}')
  assert_equal({"key" => "value"}, obj)
  obj = extract_message('26{"key":{"nested":"value"}}')
  assert_equal({"key" => {"nested" => "value"}}, obj)
  obj = extract_message('27{"key":["value1","value2"]}')
  assert_equal({"key" => ["value1", "value2"]}, obj)

  # a iso-8859-1 'ä' 
  obj = extract_message('19{"key":"umlaut%e4"}'.force_encoding("binary"))
  assert_equal "ASCII-8BIT", obj["key"].encoding.name
  assert_equal "umlaut\xe4".force_encoding("ascii-8bit"), obj["key"]
  obj = extract_message('19{"key":"umlaut%e4"}'.force_encoding("utf-8"))
  assert_equal "ASCII-8BIT", obj["key"].encoding.name
  assert_equal "umlaut\xe4".force_encoding("ascii-8bit"), obj["key"]

  # a utf-8 'ä'
  obj = extract_message('22{"key":"umlaut%c3%a4"}'.force_encoding("binary"))
  assert_equal "ASCII-8BIT", obj["key"].encoding.name
  assert_equal "umlaut\xc3\xa4".force_encoding("ascii-8bit"), obj["key"]
  obj = extract_message('22{"key":"umlaut%c3%a4"}'.force_encoding("utf-8"))
  assert_equal "ASCII-8BIT", obj["key"].encoding.name
  assert_equal "umlaut\xc3\xa4".force_encoding("ascii-8bit"), obj["key"]

  # %
  obj = extract_message('13{"key":"%25"}')
  assert_equal "ASCII-8BIT", obj["key"].encoding.name
  assert_equal "%", obj["key"]

  # invalid escape sequence
  obj = extract_message('11{"key":"%"}')
  assert_equal "ASCII-8BIT", obj["key"].encoding.name
  assert_equal "%", obj["key"]
  obj = extract_message('13{"key":"%xx"}')
  assert_equal "ASCII-8BIT", obj["key"].encoding.name
  assert_equal "%xx", obj["key"]
  obj = extract_message('14{"key":"%%25"}')
  assert_equal "ASCII-8BIT", obj["key"].encoding.name
  assert_equal "%%", obj["key"]

  # invalid characters (protocol should use 7-bit ascii only)
  obj = extract_message(%Q(14{"key":"\xe4345"}).force_encoding("binary"))
  assert_equal "ASCII-8BIT", obj["key"].encoding.name
  assert_equal "?345", obj["key"]
end

def test_roundtrip
  value = (0..255).collect{|b| b.chr("binary")}.join
  str = serialize_message({"key" => value})
  obj = extract_message(str)
  assert_equal "ASCII-8BIT", obj["key"].encoding.name
  assert_equal (0..255).collect{|i| i}, obj["key"].bytes.to_a
end

end

