$:.unshift File.join(File.dirname(__FILE__),"..","..","lib")

require 'test/unit'
require 'rtext/frontend/context'

class ContextTest < Test::Unit::TestCase

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
          C name,a1: v1,a2: "v2"|
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
          C name,a1: [v1,v2],a2: |5
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

def assert_context(expected, text)
  exp_lines = expected.strip.split("\n")
  exp_col = exp_lines.last.index("|")
  in_lines = text.strip.split("\n")
  in_col = in_lines.last.index("|")
  ctx = RText::Frontend::Context.new
  lines, col_offset = ctx.extract(in_lines)
  assert_equal exp_lines, lines
  if exp_col && in_col
    assert_equal exp_col, in_col + col_offset
  end
end

end


