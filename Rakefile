require 'rubygems/package_task'
require 'rdoc/task'

DocFiles = [
  "README.rdoc", "CHANGELOG", "MIT-LICENSE", 
  "RText_Users_Guide", 
  "RText_Protocol"]

RTextGemSpec = Gem::Specification.new do |s|
  s.name = %q{rtext}
  s.version = "0.5.0"
  s.date = Time.now.strftime("%Y-%m-%d")
  s.summary = %q{Ruby Textual Modelling}
  s.email = %q{martin dot thiede at gmx de}
  s.homepage = %q{http://ruby-gen.org}
  s.description = %q{RText can be used to derive textual languages from an RGen metamodel with very little effort.}
  s.authors = ["Martin Thiede"]
  s.add_dependency('rgen', '>= 0.6.1')
  gemfiles = Rake::FileList.new
  gemfiles.include("{lib,test}/**/*")
  gemfiles.include(DocFiles)
  gemfiles.include("Rakefile") 
  gemfiles.exclude(/\b\.bak\b/)
  s.files = gemfiles
  s.rdoc_options = ["--main", "README.rdoc", "-x", "test"]
  s.extra_rdoc_files = DocFiles
end

RDoc::Task.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files.include(DocFiles)
  rd.rdoc_files.include("lib/**/*.rb")
  rd.rdoc_dir = "doc"
end

RTextPackageTask = Gem::PackageTask.new(RTextGemSpec) do |p|
  p.need_zip = false
end	

task :prepare_package_rdoc => :rdoc do
  RTextPackageTask.package_files.include("doc/**/*")
end

task :release => [:prepare_package_rdoc, :package]

task :clobber => [:clobber_rdoc, :clobber_package]
