module ActiveMailbox
  
  module Classification
    
    # The HostClassifier attempts to classify a server by comparing it with a list of known hosts.
    
    module HostClassifier
      
      # Classify an IMAP server using a list of known hosts.
      # 
      # A ClassificationFailed error is raised if the classification failed.
      
      def classify_by_host_address(host_address)
        self.class.vendors.each do |vendor|
          if hosts = self.class.hosts(vendor)
            hosts.each { |host| return vendor if (host == host_address) }
          end
        end
        raise Errors::ClassificationFailed
      end
      
    end
    
  end
  
end
