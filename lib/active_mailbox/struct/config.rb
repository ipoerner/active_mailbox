module ActiveMailbox
  
  class Base
    
    # Generic configuration file for servers that require a username and password.
    
    class Config
      
      # Name of this configuration.
      
      attr_reader :name
      
      # Username to authenticate at the server.
      
      attr_reader :user
      
      # Encrypted password used to authenticate at the server.
      
      attr_reader :encrypted_pwd
      
      # Create a new Config.
      
      def initialize(name, user, encrypted_pwd)
        @name          = name || ""
        @user          = user
        @encrypted_pwd = encrypted_pwd
      end
      
      # Retrieve decrypted password using the secret key specified in your Active Mailbox config.
      #
      # Also see GlobalConfig.
      
      def password
        aes_key = KeyGenerator.aes_key(GlobalConfig.secret_key)
        AESEncryption.decrypt(aes_key, @encrypted_pwd)
      end
      
    end
    
  end

end
