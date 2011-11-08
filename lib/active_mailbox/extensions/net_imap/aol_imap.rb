module ActiveMailbox #:nodoc:
  
  module Extensions #:nodoc:
    
    module NetImap #:nodoc:
      
      module NoResponseFix #:nodoc:
        
        def self.included(klass)
          klass.class_eval do
            include InstanceMethods
          end
        end
        
        # The AOL IMAP server does not return anything if a SEARCH command yields no result.
        # We work around that by returning an empty array instead.
        
        module InstanceMethods
        
          def capability #:nodoc:
            cmd_synchronize("CAPABILITY") do
              send_command("CAPABILITY")
              response_last_element("CAPABILITY")
            end
          end
          
          def getacl(mailbox) #:nodoc:
            cmd_synchronize("GETACL") do
              send_command("GETACL", mailbox)
              response_last_element("ACL")
            end
          end
          
          def status(mailbox, attr) #:nodoc:
            cmd_synchronize("STATUS") do
              send_command("STATUS", mailbox, attr)
              s = response_last_element("STATUS")
              (s.nil?) ? s : s.attr
            end
          end
          
          private
          
          def response_last_element(name)
           (@responses.has_key?(name)) ? @responses.delete(name)[-1] : []
          end
          
          def search_internal(cmd, keys, charset)
            if keys.instance_of?(String)
              keys = [Net::IMAP::RawData.new(keys)]
            else
              normalize_searching_criteria(keys)
            end
            cmd_synchronize("SEARCH") do
              if charset
                send_command(cmd, "CHARSET", charset, *keys)
              else
                send_command(cmd, *keys)
              end
              response_last_element("SEARCH")
            end
          end
          
          def sort_internal(cmd, sort_keys, search_keys, charset)
            if search_keys.instance_of?(String)
              search_keys = [Net::IMAP::RawData.new(search_keys)]
            else
              normalize_searching_criteria(search_keys)
            end
            normalize_searching_criteria(search_keys)
            cmd_synchronize("SORT") do
              send_command(cmd, sort_keys, charset, *search_keys)
              response_last_element("SORT")
            end
          end
          
          def thread_internal(cmd, algorithm, search_keys, charset)
            if search_keys.instance_of?(String)
              search_keys = [Net::IMAP::RawData.new(search_keys)]
            else
              normalize_searching_criteria(search_keys)
            end
            normalize_searching_criteria(search_keys)
            send_command(cmd, algorithm, charset, *search_keys)
            response_last_element("THREAD")
          end
        
        end
      
      end
    
    end
    
  end
  
end
