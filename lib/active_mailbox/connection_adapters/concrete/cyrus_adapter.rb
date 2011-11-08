module ActiveMailbox
  
  module ConnectionAdapters
    
    # The standard adapter for Cyrus IMAP servers.
    #
    # Core features:
    #
    # * Root directory is not writeable.
  
    class CyrusAdapter < GenericAdapter
      
      # The name of this adapter.
      
      def self.adapter_name
        "Cyrus"
      end
      
      # Creates a new CyrusAdapter.
      
      def initialize(config)
        super(config)
        @standard_folders[:Trash]  = "INBOX.Trash"
        @standard_folders[:Drafts] = "INBOX.Drafts"
        @standard_folders[:Sent]   = "INBOX.Sent Items"
        @rootdir_writeable = false
        @implements_working_uidplus = true
        # unselectable parent folders are removed automatically
      end
      
      alias_method :folder_retrieve_original, :folder_retrieve  #:nodoc:
      
      # Apparently Cyrus IMAP servers do not support subscribed folders, so this method has to be
      # customized.
      
      def folder_retrieve(command, include_attr = nil, exclude_attr = nil)
        include_attr.delete(:Subscribed) if (include_attr.is_a?(Array))
        exclude_attr.delete(:Subscribed) if (exclude_attr.is_a?(Array))
        folder_retrieve_original(command, include_attr, exclude_attr)
      end
      
    end
    
    AdapterPool.register_adapter(CyrusAdapter)
    
  end
  
end
