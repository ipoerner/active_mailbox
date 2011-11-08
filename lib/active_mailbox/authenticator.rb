module ActiveMailbox
  
  # Use this module to extend a class to act as an interface to your account management.
  # For instance:
  #
  #   class LoginDataProvider
  #     include ActiveMailbox::ImapAuthenticator
  #     
  #     def self.login_data(id)
  #       ImapAccounts.find(id).attributes
  #     end
  #   end
  #
  # Also have a look at the ClassMethods module.
  
  module ImapAuthenticator
    
    # Includes the ClassMethods module and registers the class as IMAP authenticator.
    
    def self.included(klass)
      klass.extend(ClassMethods)
      ActiveMailbox::Base.authenticate_through klass
    end
    
    # ImapAuthenticator class methods.
    
    module ClassMethods
      
      # Provide a ImapConnectionSpecification instance to the Base class.
      
      def connection_specification(id)
        # TODO: verify that login_data has the appropriate keys
        options = login_data(id)
        name = options[:name]
        user = options[:user]
        encrypted_pwd = options[:encrypted_pwd]
        
        config = ActiveMailbox::Base::ImapConfig.new(name, user, encrypted_pwd, options)
        Base::ImapConnectionSpecification.new(config, options[:adapter])
      end
      
      # Stub: Provide login data for an account with a specific ID. Should be overwritten by the class
      # that includes the ImapAuthenticator module. For instance, you may retrieve the data from an
      # ActiveRecord model, like this:
      #
      #   def self.login_data(id)
      #     ImapAccounts.find(id).attributes
      #   end
      #
      # In any case, the return value should be a Hash containing the following keys:
      #
      # * <tt>:name</tt> - The name of the account (optional).
      # * <tt>:user</tt> - The login name required to authenticate at the IMAP server.
      # * <tt>:encrypted_pwd</tt> - The password required to authenticate at the IMAP server. Must be encrypted using the secret key from your ActiveMailbox YAML configuration file.
      # * <tt>:host</tt> - The host address of the IMAP server.
      # * <tt>:port</tt> - The port number used to connect to the server (optional). Will default to 143 for normal connections, and 993 for secured connections.
      # * <tt>:authentication</tt> - Authentication mechanism to use (optional). Can be PLAIN, LOGIN or CRAM-MD5. Must be supported by the server.
      # * <tt>:use_ssl</tt> - Whether to use a SSL/TLS secured connection (optional). Must be supported by the server.
      # * <tt>:certificate</tt> - The path or file containing the SSL certificate (optional).
      # * <tt>:adapter</tt> - Specify a ConnectionAdapter to use for this connection (optional). Also see ConnectionAdapters.
      
      def login_data(id)
        raise(Errors::AbstractMethodCall, "No authenticator")
      end
      
    end
    
  end
  
end