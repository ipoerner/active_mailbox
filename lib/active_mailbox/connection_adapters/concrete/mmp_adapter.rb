module ActiveMailbox
  
  module ConnectionAdapters
    
    # The standard adapter for Messaging Multiplexor IMAP servers.
  
    class MmpAdapter < GenericAdapter
      
      # The name of this adapter.
      
      def self.adapter_name
        "Messaging Multiplexor"
      end
      
    end
    
    AdapterPool.register_adapter(MmpAdapter)
    
  end
  
  class Base
    
    class ImapCapabilityArray
      
      # Retrieve all features that are unique to Messaging Multiplexor IMAP servers.
      #
      # Also see ConnectionAdapters::MmpAdapter.
      
      def features_of_mmp_adapter
        self.each { |c| return MmpAdapter.adapter_name if (c =~ /^MMP*/) }
        nil
      end
      
    end
    
  end
  
end