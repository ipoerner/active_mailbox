module ActiveMailbox
  
  module ConnectionAdapters
    
    # The standard adapter for AOL IMAP servers.
    #
    # Core features:
    #
    # * Requires a specific patch to the Net::IMAP class. See Net::AolImap.
    # * Maximum folder depth is limited to +2+.
  
    class AolAdapter < GenericAdapter
      
      # The name of this adapter.
      
      def self.adapter_name
        "aol.com"
      end
      
      # Creates a new AolAdapter.
      
      def initialize(config)
        super(config)
        @driver = Net::AolImap
        @standard_folders[:Drafts] = "Drafts"
        @standard_folders[:Sent]   = "Sent Items"
        @max_folder_depth = 2
        @implements_working_uidplus = true
        # unselectable parent folders are removed automatically
      end
      
    end
    
    AdapterPool.register_adapter(AolAdapter)
    
  end
  
  class Base
    
    class ImapCapabilityArray
      
      # Retrieve all features that are unique to AOL IMAP servers.
      # 
      # Also see ConnectionAdapters::AolAdapter.
      
      def features_of_aol_adapter
        self.each { |c| return AolAdapter.adapter_name if (c =~ /^XAOL*/) }
        nil
      end
      
    end
    
  end
  
end

module Net
  
  # This is a customized version of the Net::IMAP class, specifically for AOL IMAP servers.
  #
  # Also see ConnectionAdapters::AolAdapter.
  
  class AolImap < IMAP
    include ActiveMailbox::Extensions::NetImap::NoResponseFix
  end
  
end
