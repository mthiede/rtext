require 'rake/gempackagetask'
require 'rake/rdoctask'

RTextGemSpec = Gem::Specification.new do |s|
  s.name = %q{rtext}
  s.version = "0.1.0.pre1"
  s.date = Time.now.strftime("%Y-%m-%d")
  s.summary = %q{Ruby Textual Modelling}
  s.email = %q{martin dot thiede at gmx de}
  s.homepage = %q{http://ruby-gen.org}
  s.description = %q{RText can be used to derive textual languages from an RGen metamodel with very little effort.}
  s.has_rdoc = true
  s.authors = ["Martin Thiede"]
  gemfiles = Rake::FileList.new
  gemfiles.include("{lib,test}/**/*")
  gemfiles.include("README", "CHANGELOG", "MIT-LICENSE", "Rakefile") 
  gemfiles.exclude(/\b\.bak\b/)
  s.files = gemfiles
  s.rdoc_options = ["--main", "README", "-x", "test"]
  s.extra_rdoc_files = ["README", "CHANGELOG", "MIT-LICENSE"]
end

Rake::RDocTask.new do |rd|
  rd.main = "README"
  rd.rdoc_files.include("README", "CHANGELOG", "MIT-LICENSE", "lib/**/*.rb")
  rd.rdoc_dir = "doc"
end

RTextPackageTask = Rake::GemPackageTask.new(RTextGemSpec) do |p|
  p.need_zip = false
end	

task :prepare_package_rdoc => :rdoc do
  RTextPackageTask.package_files.include("doc/**/*")
end

task :release => [:prepare_package_rdoc, :package]

task :clobber => [:clobber_rdoc, :clobber_package]
