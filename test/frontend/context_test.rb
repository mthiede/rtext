$:.unshift File.join(File.dirname(__FILE__),"..","..","lib")

require 'minitest/autorun'
require 'rtext/frontend/context'

class ContextTest < Minitest::Test

def test_simple
  assert_context(
    %Q(
      A {
        B {
          |F bla
    ),
    %Q(
      A {
        B {
          C a1: v1, a2: "v2"
          D {
            E a1: 5
          }
          |F bla
    ))
end

def test_child_label
  assert_context(
    %Q(
      A {
        sub:
          B {
            F bla|
    ),
    %Q(
      A {
        sub:
          B {
            C a1: v1, a2: "v2"
            D {
              E a1: 5
            }
            F bla|
    ))
end

def test_child_label_array
  assert_context(
    %Q(
      A {
        sub: [
          B {
            F| bla
    ),
    %Q(
      A {
        sub: [
          B {
            C
          }
          B {
            C a1: v1, a2: "v2"
            D {
              E a1: 5
            }
            F| bla
    ))
end

def test_child_label_array2
  assert_context(
    %Q(
      A {
        B |
    ),
    %Q(
      A {
        sub: [
        ] 
        B |
    ))
end

def test_child_label_array3
  assert_context(
    %Q(
      A {
        sub: [
        ] |
    ),
    %Q(
      A {
        sub: [
        ] |
    ))
end


def test_ignore_child_lables
  assert_context(
    %Q(
      A {
        B {
          F bl|a
    ),
    %Q(
      A {
        B {
          sub:
            C a1: v1, a2: "v2"
          sub2: [
            D {
              E a1: 5
            }
          ]
          F bl|a
    ))
end

def test_linebreak
  assert_context(
    %Q(
      A {
        B {
          C name,            a1: v1,            a2: "v2"|
    ),
    %Q(
      A {
        B {
          C name,
            a1: v1,
            a2: "v2"|
    ))
end

def test_linebreak_arg_array
  assert_context(
    %Q(
      A {
        B {
          C name,            a1: [                 v1,              v2            ],             a2: |5
    ),
    %Q(
      A {
        B {
          C name,
            a1: [   
              v1,
              v2
            ], 
            a2: |5
    ))
end

def test_linebreak_empty_last_line
  assert_context(
    %Q(
      A {
        B name,          |
    ),
    %Q(
      A {
        B name,
          |
    ))
end

def test_linebreak_empty_last_line2
  assert_context(
    %Q(
      A {
        B name, |
    ),
    %Q(
      A {
        B name,
 |
    ))
end

def test_linebreak_empty_lines
  assert_context(
    %Q(
      A {
        B name,         a1: |
    ),
    %Q(
      A {
        B name, 

        a1: |
    ))
end

def test_linebreak_first_arg_array
  assert_context(
    %Q(
      A {
        B [        |
    ),
    %Q(
      A {
        B [
        |
    ))
end

def test_linebreak_first_arg_array2
  assert_context(
    %Q(
      A {
        B [          2,          |
    ),
    %Q(
      A {
        B [
          2,
          |
    ))
end

def test_linebreak_first_arg_array3
  assert_context(
    %Q(
      A {
        B [          2        ], |
    ),
    %Q(
      A {
        B [
          2
        ], |
    ))
end

def test_linebreak_backslash
  assert_context(
    %Q(
      A {
        B           arg: 1,|
    ),
    %Q(
      A {
        B \\
          arg: 1,|
    ))
end

def test_linebreak_whitespace_after_backslash
  assert_context(
    %Q(
      A {
        B             arg: 1,|
    ),
    %Q(
      A {
        B \\  
          arg: 1,|
    ))
end

def test_comment_annotation
  assert_context(
    %Q(
      A {
        B {
          |F bla
    ),
    %Q(
      A {
        # bla
        B {
          C a1: v1, a2: "v2"
          # bla
          D {
            E a1: 5
          }
          @ anno
          |F bla
    ))
end

def test_in_comment
  assert_context(
    nil,
    %Q(
      A {
        # b|la
    ))
end

def test_in_annotation
  assert_context(
    nil,
    %Q(
      A {
        # bla
        B {
          C a1: v1, a2: "v2"
          # bla
          D {
            E a1: 5
          }
          @ anno|
    ))
end

def assert_context(expected, text)
  # remove first and last lines
  # these are empty because of the use of %Q
  in_lines = text.split("\n")[1..-2]
  in_col = in_lines.last.index("|")
  in_col += 1 if in_col
  in_lines.last.sub!("|","")
  ctx = RText::Frontend::Context.new
  extracted = ctx.extract(in_lines, in_col)

  if expected.nil?
    assert_nil extracted
    return
  end

  lines, out_col = extracted
  exp_lines = expected.split("\n")[1..-2]
  exp_col = exp_lines.last.index("|")
  exp_col += 1 if exp_col
  exp_lines.last.sub!("|","")
  assert_equal exp_lines, lines
  if exp_col && in_col
    assert_equal exp_col, out_col
  end
end

end


