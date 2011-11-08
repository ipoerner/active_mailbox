module Buffering #:nodoc:
  alias_method :close_buffer, :close
end

module OpenSSL #:nodoc:
  
  module SSL #:nodoc:
    
    module SocketForwarder #:nodoc:
      
      def close
        close_buffer
        to_io.close
      end
      
    end
    
  end
  
end
