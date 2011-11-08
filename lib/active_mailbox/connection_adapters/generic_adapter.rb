module ActiveMailbox
  
  module ConnectionAdapters
    
    # The GenericAdapter is a reference implementation of a concrete connection adapter. You don't HAVE
    # to use this as a base for your own adapters, however it may be reasonable in most cases as it
    # already implements a lot of functionality. It's been separated into a couple of modules though,
    # so you may as well build your own adapter class on top of those.
    #
    # Also see the ImapStatements module.
    
    class GenericAdapter < AbstractImapAdapter
      
      include ImapStatements
      
      attr_reader :max_folder_depth  #:nodoc:
      
      # Name of this adapter.
      
      def self.adapter_name
        "Generic"
      end
      
      # Create a new GenericAdapter.
      
      def initialize(config)
        super(config)
        @standard_folders = { :Root => "", :Inbox => "Inbox", :Trash => "Trash" }
        @rootdir_writeable = true
        @max_folder_depth = nil
        @parentfolders_auto_created = true
        @implements_working_uidplus = false
        reset!
      end
      
      # Retrieve the authentication mechanism.
      
      def auth_type
        super || auth_types.last || "PLAIN"
      end
      
      # Reset adapter.
      
      def reset!
        @selected = nil
        super
      end
      
      # Open IMAP connection.
      
      def connect
        super do |host, port, use_ssl, certs, verify|
          @driver.new(host, port, use_ssl, certs, verify)
        end
        
        unless imap4rev1?
          disconnect!
          raise(Errors::ImapCommandNotSupported, "IMAP4rev1")
        end
      end
      
      # Check whether the IMAP connection is open.
      
      def connected?
        super do
          @active = begin
            @connection.noop
            true
          rescue
            false
          end
        end
      end
      
      # Authenticate at the IMAP server.
      
      def authenticate
        super do |user, password|
          if @config.authentication || login_disabled?
            @connection.authenticate(auth_type, user, password)
          else
            @connection.login(user, password)
          end
        end
        
        @max_folder_depth = 1 if @delimiter.nil?  # flat hierarchy
      end
      
      private
      
      def recurse_folder_creation?
        !@parentfolders_auto_created
      end
      
      def message_tagging_enabled?
        !@implements_working_uidplus
      end
      
    end
    
    AdapterPool.default_adapter = GenericAdapter
   
  end
  
end
