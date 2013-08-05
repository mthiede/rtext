$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rtext/tokenizer'
require 'rtext/generic'

class TokenizerTest < Test::Unit::TestCase
include RText::Tokenizer

def test_simple
  assert_tokens [
    Token.new(:identifier, "TestNode", 1, 1, 8),
    Token.new(:integer, 1, 1, 10, 10),
    Token.new(",", nil, 1, 11, 11),
    Token.new(:identifier, "bla", 1, 13, 15),
    Token.new(",", nil, 1, 16, 16),
    Token.new(:float, 0.4, 1, 18, 20),
    Token.new(",", nil, 1, 21, 21),
    Token.new(:label, "label", 1, 23, 28),
    Token.new(:integer, 4, 1, 30, 30),
    Token.new(",", nil, 1, 31, 31),
    Token.new(:string, "string", 1, 33, 40),
    Token.new(:newline, nil, 1, nil, nil) 
  ], "TestNode 1, bla, 0.4, label: 4, \"string\""
end

def test_more
  assert_tokens [
    Token.new(:identifier, "TestNode", 1, 1, 8),
    Token.new(:boolean, true, 1, 10, 13),
    Token.new(",", nil, 1, 14, 14),
    Token.new(:integer, 0xfaa, 1, 16, 20),
    Token.new(:integer, -3, 1, 22, 23),
    Token.new(:reference, "/a/b", 1, 25, 28),
    Token.new(:newline, nil, 1, nil, nil) 
  ], <<-END
TestNode true, 0xfaa -3 /a/b
  END
end

def test_comments_and_annotation
  assert_tokens [
    Token.new(:comment, " comment", 1, 1, 9),
    Token.new(:newline, nil, 1, nil, nil),
    Token.new(:annotation, " annotation", 2, 1, 12),
    Token.new(:newline, nil, 2, nil, nil),
    Token.new(:identifier, "TestNode", 3, 1, 8),
    Token.new(:comment, "comment2", 3, 10, 18),
    Token.new(:newline, nil, 3, nil, nil)
  ], <<-END
# comment
@ annotation
TestNode #comment2
  END
end

def test_generic
  tokens = do_tokenize("<name>")
  assert_equal :generic, tokens.first.kind
  assert_equal "name", tokens.first.value.string
  assert_equal 1, tokens.first.line
  assert_equal 1, tokens.first.scol
  assert_equal 6, tokens.first.ecol
end

def test_generic_bad
  tokens = do_tokenize("<a>b>")
  assert_equal :generic, tokens.first.kind
  assert_equal "a", tokens.first.value.string
  assert_equal 1, tokens.first.line
  assert_equal 1, tokens.first.scol
  assert_equal 3, tokens.first.ecol
  assert_equal :identifier, tokens[1].kind
  assert_equal :error, tokens[2].kind
end

def test_generic_percent
  tokens = do_tokenize("<%name%>")
  assert_equal :generic, tokens.first.kind
  assert_equal "name", tokens.first.value.string
  assert_equal 1, tokens.first.line
  assert_equal 1, tokens.first.scol
  assert_equal 8, tokens.first.ecol
end

def test_generic_percent_angle_close
  tokens = do_tokenize("<% a > b < c %>")
  assert_equal :generic, tokens.first.kind
  assert_equal " a > b < c ", tokens.first.value.string
  assert_equal 1, tokens.first.line
  assert_equal 1, tokens.first.scol
  assert_equal 15, tokens.first.ecol
end

def test_generic_percent_bad
  tokens = do_tokenize("<%= a %> b %>")
  assert_equal :generic, tokens.first.kind
  assert_equal "= a ", tokens.first.value.string
  assert_equal 1, tokens.first.line
  assert_equal 1, tokens.first.scol
  assert_equal 8, tokens.first.ecol
  assert_equal :identifier, tokens[1].kind
  assert_equal :error, tokens[2].kind
end

def test_error
  assert_tokens [
    Token.new(:error, "\"open", 1, 1, 5),
    Token.new(:newline, nil, 1, nil, nil)
  ], <<-END
"open
  END
end

def test_with_bom
  assert_tokens [
    Token.new(:identifier, "TestNode", 1, 1, 8),
    Token.new(:integer, 1, 1, 10, 10),
    Token.new(:newline, nil, 1, nil, nil) 
  ], "\xEF\xBB\xBFTestNode 1"
end

def test_excessive_newline
  assert_tokens [
    Token.new(:identifier, "TestNode", 3, 1, 8),
    Token.new(:newline, nil, 3, nil, nil),
    Token.new(:identifier, "TestNode", 5, 1, 8),
    Token.new(:newline, nil, 5, nil, nil) 
  ], %Q(

TestNode

TestNode

)
end

def test_only_newline
  assert_tokens [
  ], %Q(


)
end

def do_tokenize(str)
  tokenize(str, /\A\/[\/\w]+/)
end

def assert_tokens(expected, str)
  tokens = tokenize(str, /\A\/[\/\w]+/)
  assert_equal(expected, tokens)
end

end

