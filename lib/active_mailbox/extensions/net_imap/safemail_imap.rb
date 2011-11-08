module ActiveMailbox #:nodoc:
  
  module Extensions #:nodoc:
    
    module NetImap #:nodoc:
      
      module SingleSearchParamFix #:nodoc:
        
        def self.included(klass)
          klass.class_eval do
            alias_method :original_search, :search
            alias_method :original_uid_search, :uid_search
            include InstanceMethods
          end
        end
        
        # Safemail appears to behave buggy when you do UID SEARCH with only one search
        # parameter, e.g. UID SEARCH ALL. The workaround here is to simply add "ALL"
        # as an additional parameter.
        
        module InstanceMethods
          
          def uid_search(keys, charset = nil) #:nodoc:
            keys = extend_search_parameters(keys)
            return original_uid_search(keys, charset)
          end
          
          def search(keys, charset = nil) #:nodoc:
            keys = extend_search_parameters(keys)
            return original_search(keys, charset)
          end
          
          private
          
          def extend_search_parameters(keys)
            ["ALL", keys].flatten
          end
          
        end
        
      end
      
    end
    
  end
  
end
