require 'test_helper'
Dir.glob(File.join(File.dirname(__FILE__), 'extensions/test_*.rb')).each {|f| require f }

class ExtensionsTests
  
  class << self
    
    def suite
      mysuite = Test::Unit::TestSuite.new("ActiveMailbox Extensions")
      mysuite << TestCoreExtensions.suite
      mysuite << TestRmailExtensions.suite
      return mysuite
    end
  
  end
  
end
