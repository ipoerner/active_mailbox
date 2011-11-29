Gem::Specification.new do |s|
   s.platform = Gem::Platform::RUBY
   s.name = "activemailbox"
   s.version = "0.0.3"
   s.summary = "Object-oriented approach to IMAP mailboxes."
   s.description = "ActiveMailbox aims to provide easy, object-oriented access to IMAP mailboxes from within Ruby applications."

   s.required_ruby_version = '= 1.8.7'

   s.author = "Ingmar Poerner"
   s.email = "ipoerner@gmail.com"
   s.homepage = 'http://www.github.com/ipoerner/active_mailbox/'

   s.files = Dir['CHANGELOG', 'LICENSE', 'README.rdoc', 'lib/**/*']
   s.require_path = 'lib'

   s.extra_rdoc_files = %w( README.rdoc )
   s.rdoc_options.concat(['--main', 'README.rdoc'])

   s.add_dependency('activesupport', '= 2.0.0')
   s.add_dependency('rmail', '= 1.0.0')
   s.add_dependency('tmail', '= 1.2.3.1')
end
