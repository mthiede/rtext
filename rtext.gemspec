abort 'Use the rake task to build the gem' if $0 =~ /gem$/ && $*.first == 'build'

DocFiles = %w(README.rdoc CHANGELOG MIT-LICENSE RText_Users_Guide RText_Protocol)

Gem::Specification.new do |s|
  s.name = %q{rtext}
  s.version = '0.9.2'
  s.date = Time.now.strftime('%Y-%m-%d')
  s.summary = %q{Ruby Textual Modelling}
  s.email = %q{martin dot thiede at gmx de}
  s.homepage = %q{http://ruby-gen.org}
  s.description = %q{RText can be used to derive textual languages from an RGen metamodel with very little effort.}
  s.authors = ['Martin Thiede']
  s.add_dependency('rgen', '~> 0.8.2')
  s.rdoc_options = %w(--main README.rdoc -x test)
  s.extra_rdoc_files = DocFiles
end