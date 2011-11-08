module ActiveMailbox
  
  module ParseYAMLValue #:nodoc:
    
    DEFAULTS = {
      "secret_key" => "",
      "verbose" => false,
      
      "connection" => {
        "connect" => {
          "timeout"    => 5.seconds,
          "attempts"   => 3,
          "delay"      => 2.seconds
        },
        
        "login" => {
          "timeout"      => 8.seconds,
          "attempts"     => 2,
          "delay"        => 1.seconds
        },
        
        "observer_interval"  => 10.seconds,
        "task_timeout"       => 0.seconds,
        "connection_timeout" => 10.minutes,
        "session_timeout"    => 30.minutes,
      },
      
      "classification" => {
        "methods" => {
          "known_hosts"         => true,
          "server_responses"    => true,
          "server_capabilities" => true
        },
        
        "default_timeout" => 10.seconds,
        
        "capability_classifier" => {
          "min_quantity"         => 5,
          "max_distance"         => 3,
          "number_of_neighbours" => 3
        }
      }
    }
    
    private
    
    def parse_value(type, value, default = nil)
      
      result = case type
        when :fixnum
          value.is_a?(Fixnum) ? value : default
        when :timeout
          if value.is_a?(String)
           (!value.empty?) ? eval(value) : default
          else
            parse_value(:fixnum, value)
          end
        when :boolean
          (value == true || value == false) ? value : default
        when :string
          (value.is_a?(String) && !value.empty?) ? value : default
      else
        default
      end
      
      raise(ArgumentError, "Bad config format!") if result.nil?
      result
      
    end
    
  end
  
  # Deserializes the ActiveMailbox configuration and allows access to the configuration from anywhere
  # within the application.
  
  class GlobalConfig
    
    # Directory that contains the configuration file.
    
    CONFIG_DIR = "config/"
    
    # Name of the configuration file (should be in YAML format).
    
    GLOBAL_CONFIG = "active_mailbox.yml"
    
    cattr_accessor :secret_key
    cattr_accessor :verbose
    cattr_reader   :connection
    cattr_reader   :classification
    
    class << self
      
      include ParseYAMLValue
      
      # Loads a custom configuration file.
      
      def load_config!
        __load_config( DEFAULTS.merge(YAML.load(File.open(CONFIG_DIR + GLOBAL_CONFIG))) )
      end
      
      # Loads the default configuration.
      
      def set_defaults!
        __load_config( DEFAULTS )
      end
      
      private
      
      def __load_config(config)
        @@secret_key = parse_value(:string, config["secret_key"])
        @@verbose = parse_value(:boolean, config["verbose"])
        @@connection = Connection.new(config["connection"])
        @@classification = Classification.new(config["classification"])
      end
      
    end
    
    class Connection #:nodoc:
      
      include ParseYAMLValue
      
      attr_reader   :connect
      attr_reader   :login
      attr_accessor :observer_interval
      attr_accessor :task_timeout
      attr_accessor :connection_timeout
      attr_accessor :session_timeout
      
      def initialize(config = {})
        config = DEFAULTS["connection"].merge(config || {})
        
        @connect = RepeatPolicy.new(:connect, config["connect"])
        @login = RepeatPolicy.new(:login, config["login"])
        
        @observer_interval = parse_value(:timeout, config["observer_interval"])
        @task_timeout = parse_value(:timeout, config["task_timeout"])
        @connection_timeout = parse_value(:timeout, config["connection_timeout"])
        @session_timeout = parse_value(:timeout, config["session_timeout"])
      end
      
      class RepeatPolicy #:nodoc:
        
        include ParseYAMLValue
        
        attr_accessor :timeout
        attr_accessor :attempts
        attr_accessor :delay
        
        def initialize(type, config = {})
          config = DEFAULTS["connection"][type.to_s].merge(config || {})
          
          @timeout = parse_value(:timeout, config["timeout"])
          @attempts = parse_value(:fixnum, config["attempts"])
          @delay = parse_value(:timeout, config["delay"])
        end
        
      end
      
    end
    
    class Classification #:nodoc:
      
      include ParseYAMLValue
      
      attr_reader   :methods
      attr_accessor :default_timeout
      attr_reader   :capability_classifier
      
      def initialize(config = {})
        config =  DEFAULTS["classification"].merge(config || {})
        
        @methods = Methods.new(config["methods"])
        @default_timeout = parse_value(:timeout, config["default_timeout"])
        @capability_classifier = CapabilityClassifier.new(config["capability_classifier"])
      end

      class Methods #:nodoc:
        
        include ParseYAMLValue
        
        attr_accessor :known_hosts
        attr_accessor :server_responses
        attr_accessor :server_capabilities
        
        def initialize(config = {})
          config = DEFAULTS["classification"]["methods"].merge(config || {})
          
          @known_hosts = parse_value(:boolean, config["known_hosts"])
          @server_responses = parse_value(:boolean, config["server_responses"])
          @server_capabilities = parse_value(:boolean, config["server_capabilities"])
        end
      end
      
      class CapabilityClassifier #:nodoc:
        
        include ParseYAMLValue
        
        attr_accessor :min_quantity
        attr_accessor :max_distance
        attr_accessor :number_of_neighbours
        
        def initialize(config = {})
          config = DEFAULTS["classification"]["capability_classifier"].merge(config || {})
          
          @min_quantity = parse_value(:fixnum, config["min_quantity"])
          @max_distance = parse_value(:fixnum, config["max_distance"])
          @number_of_neighbours = parse_value(:fixnum, config["number_of_neighbours"])
        end
      
      end
      
    end
    
  end
  
end

ActiveMailbox::GlobalConfig.load_config!
