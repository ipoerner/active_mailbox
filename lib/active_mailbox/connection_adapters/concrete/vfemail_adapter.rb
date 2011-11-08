module ActiveMailbox
  
  module ConnectionAdapters
    
    # The standard adapter for VFEmail IMAP servers.
    #
    # Core features:
    #
    # * Maximum folder depth is limited to +21+.
    # * Root directory is not writeable.
  
    class VfemailAdapter < GenericAdapter
      
      # The name of this adapter.
      
      def self.adapter_name
        "VFEmail"
      end
      
      # Creates a new VfemailAdapter.
      
      def initialize(config)
        super(config)
        @standard_folders[:Trash]  = "INBOX.Trash"
        @max_folder_depth = 21
        @rootdir_writeable = false
        @implements_working_uidplus = true
        # unselectable parent folders are removed automatically
      end
      
    end
    
    AdapterPool.register_adapter(VfemailAdapter)
    
  end
  
end
