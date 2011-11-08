module ActiveMailbox
  
  module ConnectionAdapters
    
    # The standard adapter for Courier IMAP servers.
    #
    # Core features:
    #
    # * Root directory is not writeable.
    
    class CourierAdapter < GenericAdapter
      
      # The name of this adapter.
      
      def self.adapter_name
        "Courier"
      end
      
      # Creates a new CourierAdapter.
      
      def initialize(config)
        super(config)
        @standard_folders[:Trash] = "INBOX.Trash"
        @rootdir_writeable = false
        @implements_working_uidplus = true
        # unselectable parent folders are removed automatically
      end
      
    end
    
    AdapterPool.register_adapter(CourierAdapter)
    
  end
  
end
