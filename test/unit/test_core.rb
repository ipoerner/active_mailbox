require 'test_helper'
Dir.glob(File.join(File.dirname(__FILE__), 'core/test_*.rb')).each {|f| require f }

class CoreTests
  
  class << self
    
    def suite
      mysuite = Test::Unit::TestSuite.new("ActiveMailbox Core")
      mysuite << TestConnectionAdapter.suite
      mysuite << TestEncryption.suite
      mysuite << TestStructs.suite
      return mysuite
    end
  
  end
  
end
