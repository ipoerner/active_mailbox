module ActiveMailbox
  
  module ConnectionAdapters
    
    # The standard adapter for Gimap IMAP servers.
    #
    # Core features:
    #
    # * Maximum folder depth is limited to +8+.
    
    class GimapAdapter < GenericAdapter
      
      # The name of this adapter.
      
      def self.adapter_name
        "Gimap"
      end
      
      # Creates a new GimapAdapter.
      
      def initialize(config)
        super(config)
        @standard_folders[:Trash]  = "[Google Mail]/Trash"
        @standard_folders[:Drafts] = "[Google Mail]/Drafts"
        @standard_folders[:Sent]   = "[Google Mail]/Sent Mail"
        @max_folder_depth = 8
        # unselectable parent folders are removed automatically
      end
      
    end
    
    AdapterPool.register_adapter(GimapAdapter)
    
  end
  
end
