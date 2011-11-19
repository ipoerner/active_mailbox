require 'active_mailbox/connection_adapters/abstract/abstract_adapter'

module ActiveMailbox
  
  module ConnectionAdapters
    
    # The AbstractImapAdapter is supposed to be a prototype for concrete IMAP adapters.
  
    class AbstractImapAdapter < AbstractAdapter
      
      # The class used to create the IMAP connection (usually Net::IMAP).
      
      attr_reader :driver
      
      # The folder delimiter of the IMAP connection.
      
      attr_reader :delimiter
      
      # The server capabilities of the IMAP connection.
      
      attr_reader :capabilities
      
      # Create a new IMAP adapter from a given ImapConfig object.
      
      def initialize(config)
        super(config)
        @rwlock = ReadWriteLock.new
        @driver = Net::IMAP
        @standard_folders = Hash.new
        reset!
      end
      
      # The name of this adapter.
      
      def self.adapter_name
        "Abstract IMAP"
      end
      
      # Reset the adapter.
      
      def reset!
        @connection    = nil
        @delimiter     = nil
        @capabilities  = nil
        @authenticated = false
        super
      end
      
      # Open connection and authenticate at the IMAP server (if possible).
      
      def connect(&block)
        host    = @config.host
        use_ssl = @config.use_ssl
        port    = @config.port
        certs   = @config.certs
        verify  = @config.verify
        
        @connection = yield host, port, use_ssl, certs, verify
        
        self.capabilities = @connection.capabilities
        super
      end
      
      # Check whether or not the IMAP connection is still alive.
      
      def connected?(&block)
        @active = !(@connection.nil? || @connection.disconnected?)
        yield if @active
        super
      end
      
      # Disconnect from IMAP server.
      
      def disconnect!
        begin
          @connection.logout if authenticated?
        rescue
        end
        begin
          @connection.disconnect
        rescue
        end
        reset!
        super
      end
      
      # Authenticate at the IMAP server.
      
      def authenticate(&block)
        user     = @config.user
        password = @config.password
        
        yield user, password
        
        @delimiter ||= @connection.list("","").shift.delim
        @authenticated = true
      end
      
      # Check whether the adapter is authenticated at the IMAP server.
      
      def authenticated?
        @authenticated == true
      end
      
      # Retrieve the authentication mechanisms from the IMAP configuration.
      
      def auth_type
        @config.auth_type
      end
      
      # Create a LIST command for the IMAP connection.
      
      def list_command(location, type)
        ref  = location.list_reference(type)
        name = location.list_wildcards(type)
        ListCommand.new(ref, name)
      end
      
      # Check whether the IMAP connection supports a specific server capability.
      
      def supports?(name)
        @capabilities.synchronize { @capabilities.include?(name) }
      end
      
      # Retrieve a specific standard folder from a given symbol.
      
      def standard_folder(symbol)
        case symbol
          when :Root
            ""
          when :Inbox
            "Inbox"
        else
          @standard_folders[symbol]
        end
      end
      
      def message_retrieve(folder, search_keys, fetch_keys, sort_by, paginate)  #:nodoc:
        raise Errors::AbstractMethodCall
      end
      
      def message_exists?(folder, search_keys)  #:nodoc:
        raise Errors::AbstractMethodCall
      end
      
      def message_create(folder, message, flags)  #:nodoc:
        raise Errors::AbstractMethodCall
      end
      
      def message_update(folder, target, uid, flags, mode)  #:nodoc:
        raise Errors::AbstractMethodCall
      end
      
      def message_delete(folder, uid, dump = true)  #:nodoc:
        raise Errors::AbstractMethodCall
      end
      
      def message_duplicate(source, target, uid_list)  #:nodoc:
        raise Errors::AbstractMethodCall
      end
      
      def folder_retrieve(command, include_attr = nil, exclude_attr = nil)  #:nodoc:
        raise Errors::AbstractMethodCall
      end
      
      def folder_create(path, subscription, recurse = true)  #:nodoc:
        raise Errors::AbstractMethodCall
      end
      
      def folder_update(path, new_path, subscription, recurse = true)  #:nodoc:
        raise Errors::AbstractMethodCall
      end
      
      def folder_delete(path, recurse = true)  #:nodoc:
        raise Errors::AbstractMethodCall
      end
      
      def folder_expunge(path)  #:nodoc:
        raise Errors::AbstractMethodCall
      end
      
      def folder_status(path)  #:nodoc:
        raise Errors::AbstractMethodCall
      end
      
      private
      
      def capabilities=(caps)
        @capabilities = Base::ImapCapabilityArray.new(caps)
        @capabilities.extend(MonitorMixin)
      end
      
    end
    
  end
  
end
