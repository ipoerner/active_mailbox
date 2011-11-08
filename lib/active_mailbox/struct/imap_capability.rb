module ActiveMailbox
  
  class Base
    
    # Object-oriented presentation of an IMAP server capability.
    
    class ImapCapability
      
      AUTH_REGEX = /^AUTH=([\w]+[-_\w]+)/  #:nodoc:
      
      # Pretty common standard capabilities.
      
      STANDARD_CAPABILITIES = %w(IMAP4 IMAP4REV1 STARTTLS LOGINDISABLED AUTH=PLAIN)
      
      # Capability name.
      
      attr_accessor :name
      
      # Create a new Capability.
      
      def initialize(name)
        @name = name
      end
      
      # Compare to another capability by name.
      
      def ==(name)
        (@name == name)
      end
      
      # Match name with regular expression.
      
      def =~(regex)
        (@name =~ regex)
      end
      
      # Check whether this is an experimental capability.
      
      def experimental?
        (@name.first == "X")
      end
      
      # Check whether this is a standard capability.
      
      def standard?
        STANDARD_CAPABILITIES.include?(@name)
      end
      
      # Check whether this is a proprietary capability.
      
      def proprietary?
        include?("AOL") || include?("NETSCAPE") || include?("NOVONYX") || include?("SUN") || include?("MMP")
      end
      
      # Check whether the name includes a specific substring.
      
      def include?(str)
        @name.index(str) >= 0
      end
      
      # Check whether this capability indicates and authentication mechanism and return the auth type.
      
      def auth?
        #c.split("=").pop if c.index("AUTH=")
        if match = AUTH_REGEX.match(@name)
          match.captures.first.upcase
        else
          nil
        end
      end
      
    end
    
    # A collection of IMAP capabilities.
  
    class ImapCapabilityArray < Array
      
      # Creates a new ImapCapabilityArray.
      
      def initialize(raw_capabilities)
        unless raw_capabilities.nil?
          super(raw_capabilities.collect { |c| ImapCapability.new(c) })
        else
          super
        end
      end
      
      # Check whether this collection includes a specific capability.
      
      def include?(name)
        self.each { |c| return true if (c == name) }
        false
      end
      
      # Retrieve adapter name by distinct capabilities (experimental).
      
      def adapter_name_by_features
        self.class.instance_methods(false).each do |m|
          if (m =~ /^features_of_([\w]+[_\w]+)_adapter$/)
            return self.send(m.to_sym)
          end
        end
        nil
      end
      
      # Calculate the distance to another capability list.
      
      def distance(capabilities)
        distance_value = 0
        center_value = 0
        
        self.each do |c|
          center_value   += 1
          distance_value += 1 if capabilities.include?(c.name)
        end
        
        (center_value - (2 * distance_value))
      end
      
      # Convert collection to an array of strings.
      
      def to_a
        self.collect { |c| c.name }
      end
      
    end
    
  end
  
end