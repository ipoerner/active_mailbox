module ActiveMailbox
  
  class Base
    
    # A configuration used for an IMAP server.
  
    class ImapConfig < Config
      
      # Hostaddress of the server.
      
      attr_reader :host
      
      # Whether to use SSL encryption.
      
      attr_reader :use_ssl
      
      # Which port to use.
      
      attr_reader :port
      
      # Path to a server certificate.
      
      attr_reader :certs
      
      # The OpenSSL verification callback.
      
      attr_reader :verify
      
      # Whether to use AUTHENTICATE instead of just LOGIN.
      
      attr_reader :authentication
      
      # Authentication mechanism to use.
      
      attr_reader :auth_type
      
      attr_reader :address  #:nodoc:
      
      # Creates a new ImapConfig.
      
      def initialize (name, user, encrypted_pwd, options)
        super(name, user, encrypted_pwd)
        
        @host           =  options[:host]
        @use_ssl        = (options[:use_ssl] == false) ? false : true
        @port           =  options[:port] || ((@use_ssl) ? 993 : 143)
        @certs          =  options[:certificate]
        @verify         =  options[:verify]
        
        @authentication =  options[:authentication] ? true : false
        @auth_type      =  options[:authentication] || nil
        
        @address        = options[:address]
      end
      
    end
  
  end
  
end
