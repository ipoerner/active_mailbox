require 'test_helper'
Dir.glob(File.join(File.dirname(__FILE__), 'domain_classes/test_*.rb')).each {|f| require f }

class TestDomainClasses < Test::Unit::TestCase
  
  class << self
    
    # extend self by modules as specified by configuration
    
    def include_modules(config)
      if config.is_a?(Hash)
        if config["connection"] == true
          self.class_eval { include TestConnection }
        end
        
        if config["folders"] == true
          self.class_eval { include TestFolder }
        end
        
        if config["messages"] == true
          self.class_eval { include TestMessages }
        end
      end
    end
    
    #
    # create a Test::Unit::TestSuite instance, overwrite instance <tt>run</tt> method so that a
    # connection gets established at the beginning and shut down after the test has finished
    #
    
    def named_suite(server_name)
      
      mysuite = suite
      mysuite.instance_variable_set(:@name, server_name)
      
      def mysuite.run(*args)
        Net::IMAP.debug = TestHelper::Config.functional("debug")
        
        if record_id = TestDomainClasses.establish_connection!(@name)
          @tests.each { |test| test.instance_variable_set(:@record_id, record_id) }
          super(*args)
          TestDomainClasses.close_connection!(@name)
        end
        
        Net::IMAP.debug = false
      end
      
      mysuite
    end
    
    def establish_connection!(name)
      if id = __get_connection_id(name)
        begin
          ActiveImap.establish_connection(id)
          ActiveImap.with_connection(id) { |c|
            TestHelper::Output.puts_connection_log(name, "OK", c.class.adapter_name, c.supports?("SORT"))
          }
        rescue Exception => e
          if e.kind_of?(ActiveMailbox::Errors::ConnectionError)
            puts e.message
            puts e.backtrace
            TestHelper::Output.puts_connection_log(name, "FAILURE")
          else
            puts e.message
            raise e
          end
          
          id = nil
        end
      end
      
      id
    end
    
    def close_connection!(name)
      if id = __get_connection_id(name)
        ActiveImap.disconnect!(id)
      end
    end
    
    private
    
    def __get_connection_id(name)
      begin
        return LoginDataProvider.record_id_by_name(name)
      rescue ActiveMailbox::Errors::RecordNotFound
        TestHelper::Output.puts_connection_log(name, "NOT FOUND")
        return nil
      end
    end
    
  end
  
end
