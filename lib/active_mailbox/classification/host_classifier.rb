module ActiveMailbox
  
  module Classification
    
    # The HostClassifier attempts to classify a server by comparing it with a list of known hosts.
    
    module HostClassifier
      
      # Classify an IMAP server using a list of known hosts.
      # 
      # A ClassificationFailed error is raised if the classification failed.
      
      def classify_by_host_address(host_address)
        if vendor = self.class.hosts[host_address]
          return vendor
        end
        raise Errors::ClassificationFailed
      end
      
    end
    
  end
  
end
