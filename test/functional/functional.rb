Dir.glob(File.join(File.dirname(__FILE__), 'test_*.rb')).each {|f| puts f; require f }

require 'test/unit/testsuite'
require 'test/unit/ui/console/testrunner'

class FunctionalTestSuite
  
  @@hosts = nil
  
  class << self
    
    def suite
      
      mysuite = Test::Unit::TestSuite.new("ActiveMailbox Functional Tests")
      config = TestHelper::Config.functional
      
      if !config.nil?
        @@hosts = config["hosts"] || []
        if config.has_key?("test")
          TestDomainClasses.include_modules(config["test"])
        end
	
	def mysuite.run(*args)
	  @@hosts.each do |host|
	    self << TestDomainClasses.named_suite(host)
	  end
	  
	  super
	end
	
      end
      
      return mysuite
    end
    
  end
  
end

Test::Unit::UI::Console::TestRunner.run(FunctionalTestSuite)
