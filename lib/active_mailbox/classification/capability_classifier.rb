module ActiveMailbox
  
  module Classification
    
    # The CapabilityClassifier uses pattern recognition algorithms to classify IMAP servers using their
    # CAPABILITY responses.
    
    module CapabilityClassifier
      
      # Classify an IMAP server using its CAPABILITY response. This is done by calculating the distances
      # to a set of known CAPABILITY responses and applying the kNN-algorithm to determine the best match.
      #
      # A ClassificationFailed error is raised if the classification failed.
      
      def classify_by_capabilities(server_capabilities)
        
        # check for really unique features
        vendor = server_capabilities.adapter_name_by_features
        return vendor unless vendor.nil?
        
        if server_capabilities.length >= config.capability_classifier.min_quantity
          
          # collect and sort distances to known fingerprints
          distances = self.class.vendors.collect { |v|
            distances_to_vendor(server_capabilities, v)
          }.flatten.compact
          
          unless distances.empty?
            distances.sort! { |d1, d2| d1[:distance] <=> d2[:distance] }
            return k_nearest_neighbour(distances, config.capability_classifier.number_of_neighbours)
          end
        end
        
        raise Errors::ClassificationFailed
      end
      
      private
      
      def distances_to_vendor(server_capabilities, vendor)
        unless (fp = self.class.fingerprints(vendor)).nil?
          # calculate distances and delete object if distance is not good enough
          fp.collect { |f|
            { :distance => f.distance(server_capabilities), :vendor => vendor }
          }.delete_if { |d| d[:distance] >= config.capability_classifier.max_distance }
        end
      end
      
      # name of best result
      
      def nearest_neighbour(distances)
        distances.first[:vendor]
      end
      
      # name that appears most often within k best results
      
      def k_nearest_neighbour(distances, k = 3)
        names = distances[0..(k-1)].collect { |d| d[:vendor] }
        names_uniq = names.uniq
        
        # count appearance of first name
        name = names_uniq.shift
        max  = names.count(name)
        
        # get name with most appearances within k lowest distances
        names_uniq.each { |d| name = d if names.count(d) > max }
        
        name
      end
      
    end
    
  end
  
end
