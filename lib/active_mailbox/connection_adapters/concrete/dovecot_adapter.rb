module ActiveMailbox
  
  module ConnectionAdapters
    
    # The standard adapter for Dovecot IMAP servers.
    #
    # Core features:
    #
    # * Maximum folder depth is limited to +20+.
  
    class DovecotAdapter < GenericAdapter
      
      # The name of this adapter.
      
      def self.adapter_name
        "Dovecot"
      end
      
      # Creates a new DovecotAdapter.
      
      def initialize(config)
        super(config)
        @max_folder_depth = 20
        @implements_working_uidplus = true
        # unselectable parent folders are removed automatically
      end
      
    end
    
    AdapterPool.register_adapter(DovecotAdapter)
    
  end
  
end
