Dir.glob(File.join(File.dirname(__FILE__), 'test_*.rb')).each {|f| puts f; require f }

require 'test/unit/testsuite'
require 'test/unit/ui/console/testrunner'

class UnitTestSuite
  
  class << self
    
    def suite
      mysuite = Test::Unit::TestSuite.new("ActiveMailbox Unit Tests")
      config = TestHelper::Config.unit
      
      if !config.nil?
        if config.has_key?("test")
          test_what = config["test"]
          
          if test_what["core"] == true
            mysuite << CoreTests.suite
          end
          
          if test_what["extensions"] == true
            mysuite << ExtensionsTests.suite
          end
        end
      end
      
      return mysuite
    end
    
  end
  
end

Test::Unit::UI::Console::TestRunner.run(UnitTestSuite)
