$:.unshift(File.dirname(File.expand_path(__FILE__)))
Dir.glob(File.join(File.dirname(__FILE__), 'classification/*_classifier.rb')).each {|f| require f }
$:.shift


module ActiveMailbox
  
  # Classification of IMAP server types.

  module Classification
    
    # Classify an IMAP server.
    
    class ImapClassifier
      
      include HostClassifier
      include ResponseClassifier
      include CapabilityClassifier
      
      # List of hosts that crash the protocol when an attempt is made to logout without being logged in.
      
      LOGOUT_NOT_ALLOWED  = %w(imap.laposte.net)
      
      attr_reader :host, :capabilities, :greeting_response, :bye_response
      
      @@fingerprints = Hash.new
      @@hosts = Hash.new
      @@vendors = Array.new
      
      class << self
        
        # Add new fingerprint to the list of known fingerprints.
        
        def add_fingerprint(fingerprint,vendor)
          add_vendor(vendor)
          unless @@fingerprints.has_key?(vendor)
            @@fingerprints[vendor] = [ fingerprint ]
          else
            @@fingerprints[vendor] << fingerprint
          end
          return true
        end
        
        # Add new host to the list of known hosts.
        
        def add_host(host,vendor)
          if @@hosts.has_key?(host)
            return false
          end
          add_vendor(vendor)
          @@hosts[host] = @@vendors.find { |v| v == vendor }
          return true
        end
        
        # Add new vendor to the list of known vendors.
        
        def add_vendor(vendor)
          unless @@vendors.include?(vendor)
            @@vendors << vendor
          end
          return true
        end
        
        # Retrieve known fingerprints.
        
        def fingerprints
          @@fingerprints
        end
        
        # Retrieve known hosts.
        
        def hosts
          @@hosts
        end
        
        # Retrieve known vendors.
        
        def vendors
          @@vendors
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
