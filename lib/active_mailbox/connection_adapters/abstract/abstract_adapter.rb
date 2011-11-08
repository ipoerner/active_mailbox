module ActiveMailbox
  
  module ConnectionAdapters
    
    # The AbstractAdapter is a prototype for all kinds of connection adapters (these must not necessarily
    # be IMAP adapters).
    
    class AbstractAdapter
      
      # Server configuration.
      
      attr_reader :config
      
      # Create a new adapter from a give Config object.

      def initialize(config)
        raise(ArgumentError, "Bad config format (expected ActiveMailbox::Base::Config)") unless config.is_a?(ActiveMailbox::Base::Config)
        @config = config  # only set once!
        reset!
      end
      
      # The name of this adapter.
      
      def self.adapter_name
        "Abstract"
      end
      
      # Reset the adapter.
      
      def reset!
        @active = false
      end
      
      # Open the connection.
      
      def connect
        @active = true
      end
      
      # Reconnect the adapter.

      def reconnect!
        @active = true
      end
      
      # Close the connection.

      def disconnect!
        @active = false
      end
      
      # Check whether the adapter is connected.
      
      def connected?
        @active == true
      end
      
      # Verify the connection.

      def verify!
        reconnect! unless connected?
      end
      
      # Retrieve the raw connection instance.
      
      def raw_connection
        @connection
      end
      
    end
    
  end
  
end