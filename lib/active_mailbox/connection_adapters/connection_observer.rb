module ActiveMailbox
  
  # This is a Singleton class that's supposed to periodically let the ConnectionHandler
  # check for dead connections and remove them if necessary.
  
  class ConnectionObserver
    
    include Singleton
    
    # Start constant observation.
    
    def start
      task_timeout       = GlobalConfig.connection.task_timeout
      connection_timeout = GlobalConfig.connection.connection_timeout
      session_timeout    = GlobalConfig.connection.session_timeout
      
      intermission_time  = GlobalConfig.connection.observer_interval
      
      @observer = Thread.new do
        loop do
          ActiveMailbox::Base.cleanup!(task_timeout, connection_timeout, session_timeout)
          sleep(intermission_time.to_i)
        end
      end
    end
    
    # Stop observation.
    
    def stop
      @observer && @observer.exit
    end
    
    # Restart observation.
    
    def restart!
      stop
      start
    end
    
  end

end
