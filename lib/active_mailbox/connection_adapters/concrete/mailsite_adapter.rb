module ActiveMailbox
  
  module ConnectionAdapters
    
    # The standard adapter for MailSite IMAP servers.
    #
    # Core features:
    #
    # * Does not remove unselectable parent folders automatically.
  
    class MailsiteAdapter < GenericAdapter
      
      # The name of this adapter.
      
      def self.adapter_name
        "MailSite"
      end
      
      # Creates a new MailsiteAdapter.
      
      def initialize(config)
        super(config)
        @standard_folders[:Sent] = "Sent Items"
        @parentfolders_auto_created = false
        @implements_working_uidplus = true
      end
      
      # MailSite IMAP Servers sometimes return folders named "NIL" that we don't care about.
      
      def list(root, wildcards)
        folder_list = @connection.list(root, wildcards) || []
        folder_list.delete_if { |f| f.name.nil? }
        folder_list
      end
      
      # See <tt>list</tt> method.
      
      def lsub(root, wildcards)
        folder_list = @connection.lsub(root, wildcards) || []
        folder_list.delete_if { |f| f.name.nil? }
        folder_list
      end
      
    end
    
    AdapterPool.register_adapter(MailsiteAdapter)
    
  end
  
end
