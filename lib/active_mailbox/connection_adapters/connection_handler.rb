module ActiveMailbox
  
  module ConnectionAdapters
    
    # A simple timestamp.
    
    class Timestamp
      
      # Create a new timestamp.
      
      def initialize
        renew!
      end
      
      # Reset timestamp.
      
      def renew!
        @timestamp = Time.now
      end
      
      # Check whether timeout has occured.
      
      def timeout?(ttl)
        (!ttl.nil?) && (ttl > 0) && ((Time.now - @timestamp) > ttl)
      end
      
    end
    
    # A task that is being executed on a connection.
    
    class Task
      
      # The actual task is supposed to be a Thread object.
      
      attr_reader :task
      
      # Create a new task.
      
      def initialize(t)
        @task = t
        @timestamp = Timestamp.new
      end
      
      # Check whether a timeout has occured on the task.
      
      def timeout?(ttl)
        @timestamp.timeout?(ttl)
      end
      
      # Terminate task.
      
      def terminate!
        @task.kill unless @task.nil?
      end
      
    end
    
    # A collection of active Task objects.
    
    class TaskStack
      
      # Create a new collection of tasks.
      
      def initialize
        @tasks = Array.new.extend(MonitorMixin)
        @timestamp = Timestamp.new
      end
      
      # Add a task and start counting.
      
      def start_task(task)
        @tasks.synchronize {
          @tasks << Task.new(task)
          @timestamp.renew!
        }
        task
      end
      
      # Finish a task.
      
      def end_task(task)
        @tasks.synchronize {
          @tasks.delete_if { |t| t.task == task }
          @timestamp.renew!
        }
      end
      
      # Check whether a specific task exists.
      
      def exists?(task, &block)
        @tasks.synchronize {
          if (result = @tasks.index { |t| t.task == task })
            yield
          end
          result
        }
      end
      
      # End all tasks of this collection.
      
      def reset!
        @tasks.synchronize {
          @tasks.delete_if { |t| t.terminate! }
          @timestamp = Timestamp.new
        }
      end
      
      # Check whether a task timout has occured.
      
      def task_timeout?(ttl)
        @tasks.synchronize {
          __task_timeout?(ttl)
        }
      end
      
      # Check whether a connection timeout has occured.
      
      def connection_timeout?(ttl)
        @tasks.synchronize {
          __connection_timeout?(ttl)
        }
      end
      
      # Check whether a timeout has occured (task or connection).
      
      def timeout?(task_ttl, connection_ttl)
        @tasks.synchronize {
          __task_timeout?(task_ttl) || __connection_timeout?(connection_ttl)
        }
      end
      
      private
      
      def __task_timeout?(ttl)
        @tasks.each do |t|
          return true if t.timeout?(ttl)
        end
        false
      end
      
      def __connection_timeout?(ttl)
        @timestamp.timeout?(ttl)
      end
      
    end
    
    # A class that handles a connection. Consists of a ImapConnectionSpecification and a concrete
    # ConnectionAdapter.
    
    class ConnectionHandler
      
      # Timeout for a LOGOUT command.
      
      DISCONNECT_TIMEOUT = 2.seconds
      
      # Timeout for a NOOP command.
      
      NOOP_TIMEOUT       = 2.seconds
      
      # Creates a new ConnectionHandler object.
      
      def initialize
        @rwlock = ReadWriteLock.new
        
        @rwlock.write {
          @connection    = nil
          @specification = nil
          @taskbox       = TaskStack.new
        }
      end
      
      # Establish the connection using an ImapConnectionSpecification object.
      
      def establish(spec)
        @rwlock.write {
          @specification = spec
          @connection    = spec.new_connection
          __connect
        }
      end
      
      # Execute a block on the connection.
      
      def execute(timeout = nil, &block)
        result = nil
        
        if timeout.nil?
          @rwlock.read {
            result = yield @connection
          }
        else
          verify!
          @rwlock.read {
            # re-verify connectivity
            if !__connected?
              @taskbox.reset!
              raise Errors::ConnectionTerminated
            else
              result = __execute(timeout, &block)
            end
          }
        end
        
        result
      end
      
      # Open the connection.
      
      def connect
        @rwlock.write {
          __connected? || __connect
        }
      end
      
      # Close the connection.
      
      def disconnect!(force_disconnect = false)
        if force_disconnect
          # force disconnect (kill all pending tasks first)
          @rwlock.block! {
            @taskbox.reset!
            __disconnect!
          }
        else
          # wait for write lock and disconnect
          @rwlock.write {
            __connected? && __disconnect!
          }
        end
      end
      
      # Verify the connection. Will reconnect unless the connection is established already.
      
      def verify!
        @rwlock.read {
          unless __connected?
            @taskbox.reset!
          end
        }
        @rwlock.write {
          __reconnect! unless __connected?
        }
      end
      
      # Check whether the connection is open.
      
      def connected?
        @rwlock.read {
          __connected?
        }
      end
      
      # Check whether a timeout has occured on a task or the connection.
      
      def timeout?(task_ttl, connection_ttl)
        @taskbox.timeout?(task_ttl, connection_ttl)
      end
      
      # Check whether a timeout has occured on a task.
      
      def task_timeout?(task_ttl)
        @taskbox.task_timeout?(task_ttl)
      end
      
      # Check whether a timeout has occured on the connection.
      
      def connection_timeout?(connection_ttl)
        @taskbox.connection_timeout?(connection_ttl)
      end
      
      private
      
      def __execute(timeout, &block)
        exception = nil
        result    = nil
        task      = nil
        
        begin
          task = @taskbox.start_task(Thread.new { yield @connection })
          
          if task.join(timeout.to_i).nil?
            exception = Errors::ConnectionTimeout
          else
            unless @taskbox.exists?(task) { result = task.value }
              # thread has been terminated from outside
              task = nil
              exception = Errors::ConnectionTerminated
            end
          end
        rescue Exception => exception
          unless exception.is_a?(Errors::ActiveMailboxError)
            # encapsulate unknown errors in ConnectionError object
            exception = Errors::ConnectionError.new(exception)
          end
        ensure
          task.kill unless task.nil?
          @taskbox.end_task(task)
          unless exception.nil?
            raise exception
          end
        end
        
        result
      end
      
      def __connect
        if !__connected?
          @taskbox.reset!
          @connection.reset!
          
          config = GlobalConfig.connection.connect
          
          config.attempts.times {
            begin
              __execute(config.timeout) { |conn| conn.connect }
            rescue
              sleep(config.delay.to_i)
            end
            
            break if @connection.connected?
          }
          
          raise Errors::ConnectionFailed unless @connection.connected?
          
          config = GlobalConfig.connection.login
          
          config.attempts.times {
            begin
              __execute(config.timeout) { |conn| conn.authenticate }
            rescue Exception => e
              sleep(config.delay.to_i)
            end
            
            break if @connection.authenticated?
          }
          
          raise Errors::AuthenticationFailed unless @connection.authenticated?
        end
        
      end
      
      def __disconnect!
        if __connected?
          begin
            if __connected?
              __execute(DISCONNECT_TIMEOUT) { |conn| conn.disconnect! }
            end
          ensure
            @taskbox.reset!
            @connection.reset!
          end
        end
      end
      
      def __reconnect!
        __disconnect!
        __connect
      end
      
      def __connected?
        return false if @connection.nil?
        begin
          __execute(NOOP_TIMEOUT) { |conn| conn.connected? && conn.authenticated? }
        rescue Errors::ConnectionTimeout
          @connection.reset!
          false
        end
      end
      
    end
    
  end

end
