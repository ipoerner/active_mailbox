module ActiveMailbox
  
  class Base
    
    # An ImapConnectionSpecification combines an ImapConfig with a concrete adapter and thus
    # provides everything that's required to manage an IMAP connection.
    
    class ImapConnectionSpecification
      
      # The IMAP server config.
      
      attr_reader :config
      
      # The concrete adapter class.
      
      attr_reader :adapter_class
      
      # Creates a new ImapConnectionSpecification.
      
      def initialize (login_data, adapter_name)
        unless login_data.is_a?(ActiveMailbox::Base::ImapConfig)
          raise(ArgumentError, "Bad spec format (expected ActiveMailbox::Base::ImapConfig)")
        end
        
        @config = login_data
        @adapter_class = get_adapter_class(adapter_name)
        
        self
      end
      
      # Creates an instance of the adapter class specified.
      
      def new_connection
        raise(Errors::AdapterNotSpecified) if @adapter_class.nil?
        @adapter_class.new(@config)
      end
      
      private
      
      def get_adapter_class(adapter_name = nil)
        if adapter_name.nil?
          classifier = ActiveMailbox::Classification::ImapClassifier.new(@config)
          adapter_name = classifier.classify
        end
        # must reckon with valid adapter_name but non-existant adapter class 
        __adapter(adapter_name) || __default
      end
      
      def __adapter(adapter_name)
        begin
          ActiveMailbox::ConnectionAdapters::AdapterPool.retrieve_adapter(adapter_name)
        rescue Errors::AdapterNotFound
          nil
        end
      end
      
      def __default
        ActiveMailbox::ConnectionAdapters::AdapterPool.default_adapter
      end
      
    end
    
  end
  
end
