module ActiveMailbox
  
  module Configuration
    
    class Classification
      
      CLASSIFICATION_CONFIG = "config/classification.yml"
      
      class << self
        
        def load_config!
          begin
            parse_config(YAML.load(File.open(CLASSIFICATION_CONFIG)))
          rescue Errno::ENOENT
          end
        end
        
        private
        
        def parse_config(input)
          input.each { |entry|
            vendor = entry[:id]
            ActiveMailbox::Classification::ImapClassifier.add_vendor(vendor)
            unless entry[:hosts].nil?
              entry[:hosts].each do |h|
                unless ActiveMailbox::Classification::ImapClassifier.add_host(h, vendor)
                  raise(Errors::ConfigurationError, "Duplicate host address in '" + CLASSIFICATION_CONFIG + "'")
                end
              end
            end
            unless entry[:capabilities].nil?
              entry[:capabilities].each do |c|
                ActiveMailbox::Classification::ImapClassifier.add_fingerprint(c, vendor)
              end
            end
          }
        end
        
      end
      
    end
    
  end

end

ActiveMailbox::Configuration::Classification.load_config!
