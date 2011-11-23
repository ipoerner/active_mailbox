require 'rubygems'
require 'rake/testtask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'rake/rdoctask'

if RUBY_VERSION < "1.9"
  require 'rcov/rcovtask'
  RUBY_LIBS = "/usr/local/lib/site_ruby/1.8/"
  task :default => [ :rcov ]
else
  module Rcov
    class RcovTask
      def initialize(&block)
        raise Exception, "Abstract method call!"
      end
    end
  end
  task :default => [ :test ]
end

#
# Tests
#

#TEST_DIRS = %w[unit integration functional]
TEST_DIRS = %w[unit functional]

# traditional Rake Tests
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = TEST_DIRS.collect { |target| FileList["test/#{target}/#{target}.rb"] }.compact
  t.options = "--verbose=verbose"
  t.verbose = true
end

if RUBY_VERSION < "1.9"
  # Rcov tests
  Rcov::RcovTask.new do |t|
    t.libs << %w(lib)
    t.libs << %w(test)
    t.test_files = TEST_DIRS.collect { |target| FileList["test/#{target}/#{target}.rb"] }.flatten
    t.output_dir = "coverage"
    t.verbose = true
    t.rcov_opts << '--exclude "' + RUBY_LIBS + '"'
  end
end

##
## Distribution
##
#
#task :dist => [:repackage, :gem, :rdoc]
#task :distclean => [:clobber_package, :clobber_rdoc]
#
##
## Documentation
##

Rake::RDocTask.new do |rdoc|
  rdoc.title = "Active Mailbox - Easy access to IMAP mailboxes in Ruby"
  rdoc.rdoc_files.include("README.rdoc")
  rdoc.rdoc_files.include("config/README.rdoc")
  rdoc.rdoc_files.include("config/classification/README.rdoc")
  rdoc.rdoc_files.include("test/config/README.rdoc")
  rdoc.rdoc_files.include("./lib/**/*.rb")
end

##
## Packaging
## 
#
#spec = Gem::Specification.new do |s|
#    s.name = "active_mailbox"
#    s.version = "0.0.2"
#    s.author = "Ingmar Poerner"
#    s.email = "ipoerner@gmail.com"
#    s.summary = "Active Mailbox aims to provide easy e-mail integration into ruby applications"
#    s.has_rdoc = true
#    s.files = Dir["lib/**/*.rb"] + Dir["test/*"]
#    s.add_dependency 'rmail'
#    s.add_dependency 'tmail'
#end
#
#Rake::GemPackageTask.new(spec) do |s|
#end
#
#Rake::PackageTask.new(spec.name, spec.version) do |p|
#    p.need_tar_gz = true
#    p.need_zip = true
#    p.package_files.include("./lib/**/*.rb")
#    p.package_files.include("Rakefile")
#    p.package_files.include("./test/**/*")
#end
