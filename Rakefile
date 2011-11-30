require 'rubygems'
require 'rake/testtask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'rake/rdoctask'

#
# Encryption helper
#

desc "Generate AES encryption key to use in main configuration file"
task :generate_aes_key do
  require 'lib/active_mailbox'
  puts "New AES key: " + ActiveMailbox::KeyGenerator.sha2_hash
end

desc "Encrypt passphrase for use in test configuration files"
task :encrypt_passphrase do
  require 'readline'
  require 'lib/active_mailbox'
  begin
    aes_key = Readline.readline("Please enter your AES key: ", false)
    aes_key = ActiveMailbox::KeyGenerator.aes_key(aes_key)
    str = Readline.readline("Please enter your plain passphrase: ", false)
    str = ActiveMailbox::AESEncryption.encrypt(aes_key, str)
    puts "Encrypted passphrase: " + str
  rescue
    puts "Encryption failed!"
  end
end

desc "Decrypt passphrase used in test configuration files"
task :decrypt_passphrase do
  require 'readline'
  require 'lib/active_mailbox'
  begin
    aes_key = Readline.readline("Please enter your AES key: ", false)
    aes_key = ActiveMailbox::KeyGenerator.aes_key(aes_key)
    str = Readline.readline("Please enter your encrypted passphrase: ", false)
    str = ActiveMailbox::AESEncryption.decrypt(aes_key, str)
    puts "Plain passphrase: " + str
  rescue
    puts "Decryption failed!"
  end
end

#
# Testing
#

#TEST_DIRS = %w[unit integration functional]
TEST_DIRS = %w[unit functional]

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = TEST_DIRS.collect { |target| FileList["test/#{target}/#{target}.rb"] }.compact
  t.options = "--verbose=verbose"
  t.verbose = true
end

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

if RUBY_VERSION < "1.9"
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

spec = eval(File.read('activemailbox.gemspec'))

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end

##
## Distribution
##

desc "Create distribution (packaging & documentation)"
task :dist => [:repackage, :gem, :rdoc]

desc "Cleanup distribution"
task :distclean => [:clobber_package, :clobber_rdoc]

##
## Misc
##

desc "Cleanup everything"
task :clean => [:distclean, :clobber_rcov]
