module ActiveMailbox
  
  module ConnectionAdapters
    
    # The standard adapter for SAFe-mail IMAP servers.
    #
    # Core features:
    #
    # * Requires a specific patch to the Net::IMAP class. See Net::SafemailImap.
    # * Maximum folder depth is limited to +1+. This is due to lazy updates of the LIST response.
  
    class SafemailAdapter < GenericAdapter
      
      # The name of this adapter.
      
      def self.adapter_name
        "SAFe-mail"
      end
      
      # Creates a new SafemailAdapter.
      
      def initialize(config)
        super(config)
        @driver = Net::SafemailImap
        @standard_folders[:Drafts] = "Drafts"
        @standard_folders[:Sent]   = "Sent"
        @max_folder_depth          = 1
        # SafeMail actually allowes a folder depth > 1 but it's very lazy in updating it's LIST response
        # that's why inferior folders remain disabled for now (it would screw up the tests, and the risk
        # of having confusing folder hierarchies is heavily reduced)
        #@max_folder_depth           = 8
        #@parentfolders_auto_created = false
      end
      
    end
    
    AdapterPool.register_adapter(SafemailAdapter)
    
  end
  
end

module Net
  
  # This is a customized version of the Net::IMAP class, specifically for SAFe-mail IMAP servers.
  #
  # Also see ConnectionAdapters::SafemailAdapter.
  
  class SafemailImap < IMAP
    include ActiveMailbox::Extensions::NetImap::SingleSearchParamFix
  end
  
end
