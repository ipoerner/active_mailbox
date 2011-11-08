module ActiveMailbox
  
  module ConnectionAdapters
    
    # The standard adapter for Lavabit IMAP servers.
    #
    # Core features:
    #
    # * Requires a specific patch to the Net::IMAP class. See Net::LavabitImap.
    # * Maximum folder depth is limited to +7+.
  
    class LavabitAdapter < GenericAdapter
      
      # The name of this adapter.
      
      def self.adapter_name
        "lavabit.com"
      end
      
      # Creates a new LavabitAdapter.
      
      def initialize(config)
        super(config)
        @driver = Net::LavabitImap
        @standard_folders[:Drafts] = "Drafts"
        @standard_folders[:Sent]   = "Sent Items"
        @max_folder_depth = 7
        @implements_working_uidplus = false
        # unselectable parent folders are removed automatically
      end
      
      # As long as lavabit does not support UNSELECT and also cannot cope with invalid SELECT calls,
      # this method can't do much except to unset the @selected attribute.
      
      def unselect(force_unselect = false)
        if !@selected.nil? || force_unselect
          @selected = nil
          if supports_unselect?
            @connection.unselect
          end
        end
      end
      
      # Customized LIST command for Lavabit IMAP servers.
      
      def list_command(location, type)
        ref  = location.parent_path || ""
        name = location.list_wildcards(type)
        ListCommand.new(ref, name)
      end
      
    end
    
    AdapterPool.register_adapter(LavabitAdapter)
    
  end
  
end

module Net
  
  # This is a customized version of the Net::IMAP class, specifically for Lavabit IMAP servers.
  #
  # Also see ConnectionAdapters::LavabitAdapter.
  
  class LavabitImap < IMAP
    include ActiveMailbox::Extensions::NetImap::CacheCommandsFix
  end
  
end
