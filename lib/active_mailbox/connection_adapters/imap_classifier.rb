module ActiveMailbox
  
  # Classification of IMAP server types.

  module Classification
    
    # Classify an IMAP server.
    
    class ImapClassifier
      
      include HostClassifier
      include ResponseClassifier
      include CapabilityClassifier
      
      # Directory that contains the classification config files.
      
      CLASSIFICATION_DIR  = "config/classification/"
      
      # Config file for server capabilities (should be in YAML format).
      
      CONFIG_CAPABILITIES = "capabilities.yml"
      
      # Config file for known hosts (should be in YAML format).
      
      CONFIG_HOSTS        = "hosts.yml"
      
      # Config file for known vendors (should be in YAML format).
      
      CONFIG_VENDORS      = "vendors.yml"
      
      # List of hosts that crash the protocol when an attempt is made to logout without being logged in.
      
      LOGOUT_NOT_ALLOWED  = %w(imap.laposte.net)
      
      attr_reader :host, :capabilities, :greeting_response, :bye_response
      
      class << self
        
        # Load information needed for the classification from config files.
        
        def load_config!
          @@hosts        ||= YAML.load(File.open(CLASSIFICATION_DIR + CONFIG_HOSTS))
          @@capabilities ||= YAML.load(File.open(CLASSIFICATION_DIR + CONFIG_CAPABILITIES))
          @@vendors      ||= YAML.load(File.open(CLASSIFICATION_DIR + CONFIG_VENDORS))
        end
        
        # Retrieve known vendors.
        
        def vendors
	  if @@vendors
            @@vendors.keys
          else
            []
          end
        end
        
        # Retrieve fingerprints associated with a specific IMAP server.
        
        def fingerprints(key)
          unless @@vendors[key].nil? || (capability_lists = @@vendors[key][:capabilities]).nil?
            capability_lists.collect { |capability_ids|
              # get real names of capabilities and create ImapCapabilityArray
              Base::ImapCapabilityArray.new(capability_ids.collect { |id| @@capabilities[id] })
            }
          else
            []
          end
        end
        
        # Retrieve all hosts associated with a specific IMAP server.
        
        def hosts(key)
          unless @@vendors[key].nil?
            @@vendors[key][:hosts].collect { |id| @@hosts[id] }
          else
            []
          end
        end
        
      end
      
      # Creates a new ImapClassifier from given ImapConfig object.
      
      def initialize(config)
        @host   = config.host
        use_ssl = config.use_ssl
        port    = config.port
        certs   = config.certs
        verify  = config.verify
        
        connection = Net::IMAP.new(@host, port, use_ssl, certs, verify)
        
        @greeting_response = connection.greeting_response
        @capabilities = Base::ImapCapabilityArray.new(connection.capabilities)
          
        unless (LOGOUT_NOT_ALLOWED.include?(@host))
          connection.logout
          @bye_response = connection.bye_response
        end
          
        connection.disconnect
      end
      
      # Actual classification; returns name of adapter.
      
      def classify
        name = nil
        method = "Default Adapter"
        
        if classify_by_known_hosts?
          method = "Known Hosts"
          name = host_lookup
        end
        
        if name.nil?
          if classify_by_server_responses?
            method = "Greeting Response"
            name = greeting_lookup
            
            if name.nil?
              method = "Bye Response"
              name = bye_lookup
            end
          end
        end
        
        if name.nil?
          if classify_by_server_capabilities?
            method = "Capability Values"
            name = capability_lookup
          end
        end
        
        if !name.nil? && GlobalConfig.verbose
          puts "DEBUG: <#{name}> classified by <#{method}>"
        end
        
        return name
      end
      
      private
      
      def config
        GlobalConfig.classification
      end
      
      def classify_by_known_hosts?
        config.methods.known_hosts
      end
      
      def classify_by_server_responses?
        config.methods.server_responses
      end
      
      def classify_by_server_capabilities?
        config.methods.server_capabilities
      end
      
      def host_lookup
        begin
          classify_by_host_address(@host)
        rescue Errors::ClassificationFailed
          nil
        end
      end
      
      def greeting_lookup
        begin
          classify_by_server_response(@greeting_response)
        rescue Errors::ClassificationFailed
          nil
        end
      end
      
      def bye_lookup
        begin
          classify_by_server_response(@bye_response)
        rescue Errors::ClassificationFailed
          nil
        end
      end
      
      def capability_lookup
        begin
          classify_by_capabilities(@capabilities)
        rescue Errors::ClassificationFailed
          nil
        end
      end
      
    end
    
  end
  
end

ActiveMailbox::Classification::ImapClassifier.load_config!
