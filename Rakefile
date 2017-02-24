require 'rubygems/package_task'

require 'rake'
require 'rdoc/task'

RTextGemSpec = eval(File.read('rtext.gemspec'))

gemfiles = Rake::FileList.new
gemfiles.include('{lib,test}/**/*')
gemfiles.include(%w(README.rdoc CHANGELOG MIT-LICENSE RText_Users_Guide RText_Protocol))
gemfiles.include('Rakefile')
gemfiles.exclude(/\b\.bak\b/)
RTextGemSpec.files = gemfiles

RDoc::Task.new do |rd|
  rd.main = 'README.rdoc'
  rd.rdoc_files.include(RTextGemSpec.extra_rdoc_files)
  rd.rdoc_files.include('lib/**/*.rb')
  rd.rdoc_dir = 'doc'
end

RTextPackageTask = Gem::PackageTask.new(RTextGemSpec) do |p|
  p.need_zip = false
end	

task :prepare_package_rdoc => :rdoc do
  RTextPackageTask.package_files.include('doc/**/*')
end

task :release => [:prepare_package_rdoc, :package]

task :clobber => [:clobber_rdoc, :clobber_package]

require 'rake/testtask'

::Rake::TestTask.new(:test) do |t|
  t.test_files = ['test/rtext_test.rb']
  t.warning = false
end
