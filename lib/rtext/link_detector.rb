require 'rtext/tokenizer'
require 'rtext/context_builder'

module RText

class LinkDetector
include RText::Tokenizer

def initialize(lang)
  @lang = lang
end

LinkDesc = Struct.new(:element, :feature, :backward, :value, :scol, :ecol)

# column numbers start at 1
def detect(lines, column)
  # make sure there is a space at the end of the line
  # otherwise an important attribute value (e.g. the local name) might be missing in the
  # context model since the context builder removes it as "just being completed"
  lines.last.concat(" ")
  current_line = lines.last
  context = ContextBuilder.build_context(@lang, lines, lines.last.size)
  tokens = tokenize(lines.last, @lang.reference_regexp)
  token = tokens.find{|t| t.scol && t.scol <= column && t.ecol && t.ecol >= column}
  if context && context.element && token &&
      [:reference, :integer, :string, :identifier].include?(token.kind)
    if column > 1
      line_prefix = lines.last[0..column-2]
    else
      line_prefix = ""
    end
    context2 = ContextBuilder.build_context(@lang, lines, line_prefix.size) 
    bwref_attr = @lang.backward_ref_attribute.call(context.element.class.ecore)
    if bwref_attr
      is_backward = (context2.feature && context2.feature.name == bwref_attr)
    else
      is_backward = (token.kind == :identifier && line_prefix =~ /^\s*\w*$/)
    end
    is_backward = is_backward ? true : false
    LinkDesc.new(context.element, context2.feature, is_backward, token.value, token.scol, token.ecol)
  else
    nil
  end
end

end

end
