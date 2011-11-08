module ActiveMailbox
  
  module ConnectionAdapters
    
    # The ConnectionPool contains a number of connection handler.
    
    class ConnectionPool
      
      # Creates a new connection handler.
      
      def initialize
        @rwlock = ReadWriteLock.new
        @rwlock.write {
          @connection_handlers = Hash.new
        }
      end
      
      # Add a connection handler.
      
      def add_connection_handler(id)
        @rwlock.write {
          __add_connection_handler(id)
        }
      end
      
      # Remove a connection handler.
      
      def del_connection_handler(id)
        @rwlock.write {
          __del_connection_handler(id)
        }
      end
      
      # Check whether a connection handler exists in the pool.
      
      def connection_handler_exists?(id)
        @rwlock.read {
          __connection_handler_exists?(id)
        }
      end
      
      # Add a new connection handler and establish connection immediately.
      
      def establish(id, spec)
        @rwlock.write {
          __add_connection_handler(id)
          @connection_handlers[id].establish(spec)
        }
      end
      
      # Disconnect a connection handler (or all of them).
      
      def disconnect!(id = nil)
        @rwlock.read {
          if id.nil?
            @connection_handlers.each_value do |handler|
              handler.disconnect!
            end
          else
            verify_connection_handler_exists!(id)
            @connection_handlers[id].disconnect!
            __del_connection_handler(id)
          end
        }
      end
      
      # Remove any connection handlers that have timed out.
      
      def cleanup!(task_ttl, connection_ttl, session_ttl)
        @rwlock.write {
          @connection_handlers.each do |id, handler|
            if handler.connection_timeout?(session_ttl)
              handler.disconnect!(true)
              __del_connection_handler(id) 
            elsif handler.timeout?(task_ttl, connection_ttl)
              handler.disconnect!(true)
            end
          end
        }
      end
      
      # Verify connectivity of a connection handler (or all of them).
      
      def verify_all!(id = nil)
        @rwlock.read {
          verify_connection_handler_exists!(id)
          if id.nil?
            @connection_handlers.each_value do |handler|
              handler.verify!
            end
          else
            @connection_handlers[id].verify!
          end
        }
      end
      
      # Yield a codeblock on a specific connection.
      
      def with_connection(id, timeout = nil, &block)
        @rwlock.read {
          verify_connection_handler_exists!(id)
          @connection_handlers[id].execute(timeout, &block)
        }
      end
      
      # Check whether a specific connection handler is connected.
      
      def connected?(id = nil)
        @rwlock.read {
          verify_connection_handler_exists!(id)
          @connection_handlers[id].connected?
        }
      end
      
      private
      
      def __add_connection_handler(id)
        @connection_handlers[id] = ConnectionHandler.new
      end
      
      def __del_connection_handler(id)
        @connection_handlers.delete(id)
      end
      
      def __connection_handler_exists?(id)
        !@connection_handlers.nil? && @connection_handlers.has_key?(id)
      end
      
      def verify_connection_handler_exists!(id)
        raise Errors::ConnectionNotEstablished if (!id.nil? && !__connection_handler_exists?(id))
      end
      
    end
  
  end

  class Base

    cattr_accessor :connection_pool, :instance_writer => false
    @@connection_pool = ConnectionAdapters::ConnectionPool.new

    class << self
      
      # Establish a new connection. Queries the <tt>connection_specification</tt> method in order to
      # acquire an ImapConnectionSpecification object that corresponds with +id+.
      
      def establish_connection(id)
        spec = connection_specification(id)
        raise Errors::ArgumentError if spec.nil?
        
        @@connection_pool.establish(id, spec)
      end
      
      delegate :connected?, :cleanup!, :disconnect!, :verify_all!, :with_connection, :to => :connection_pool
      
    end
    
  end
  
end
