module OpenSSL #:nodoc:

  module Buffering #:nodoc:
    alias_method :close_buffer, :close
  end
  
  module SSL #:nodoc:
    
    module SocketForwarder #:nodoc:
      
      def close
        close_buffer
        to_io.close
      end
      
    end
    
  end
  
end
