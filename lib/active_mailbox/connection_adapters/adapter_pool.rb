module ActiveMailbox
  
  module ConnectionAdapters
    
    # Store available adapter classes in a pool so that they can easily
    # be retrieved by name and a default adapter can be specified.
    
    class AdapterPool
      
      @@default_adapter = nil
      @@loaded_adapters = {}
      
      class << self
        
        # Add new adapter to pool.
      
        def register_adapter(klass)
          if is_adapter?(klass)
            @@loaded_adapters[klass.adapter_name] = klass
            return true
          end
          false
        end
        
        # Remove adapter from pool.
        
        def unregister_adapter(name)
          @@loaded_adapters.delete(name)
        end
        
        # Find adapter by name. Raises AdapterNotFound error if adapter doesn't exist.
        
        def retrieve_adapter(name = nil)
          if name.nil?
            @@default_adapter
          else
            @@loaded_adapters[name] || (raise(Errors::AdapterNotFound, name))
          end
        end
        
        # Set default adapter.
        
        def default_adapter=(klass)
          if is_adapter?(klass)
            @@default_adapter = klass
            return true
          end
          false
        end
        
        # Retrieve default adapter.
        
        def default_adapter
          @@default_adapter
        end
        
        private
        
        def is_adapter?(klass)
          until klass.superclass.nil? do
            return true if (klass.superclass == AbstractImapAdapter)
            klass = klass.superclass
          end
          false
        end
      
      end
      
    end
    
  end
  
end
