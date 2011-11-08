module ActiveMailbox
  
  module ConnectionAdapters
    
    # The standard adapter for Web.de IMAP servers.
    # Core features:
    #
    # * Maximum folder depth is limited to +1+.
  
    class WebdeAdapter < GenericAdapter
      
      # The name of this adapter.
      
      def self.adapter_name
        "Web.de"
      end
      
      # Creates a new WebdeAdapter.
      
      def initialize(config)
        super(config)
        @standard_folders[:Trash]  = "Papierkorb"
        @standard_folders[:Drafts] = "Entwurf"
        @standard_folders[:Sent]   = "Gesendet"
        @max_folder_depth = 1
        @parentfolders_auto_created = false
      end
      
    end
    
    AdapterPool.register_adapter(WebdeAdapter)
    
  end
  
end
