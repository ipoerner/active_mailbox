module ActiveMailbox
  
  module Classification
    
    # The ResponseClassifier looks for the name of a known IMAP server in a given server response.
    
    module ResponseClassifier
      
      # Classifiy an IMAP server using an arbitrary server response.
      # 
      # A ClassificationFailed error is raised if the classification failed.
      
      def classify_by_server_response(server_response)
        server_response.downcase!
        self.class.vendors.each do |vendor|
          return vendor if server_response.include?(vendor.downcase)
        end
        raise Errors::ClassificationFailed
      end
      
    end
    
  end
  
end
