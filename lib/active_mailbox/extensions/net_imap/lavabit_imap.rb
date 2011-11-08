module ActiveMailbox #:nodoc:
  
  module Extensions #:nodoc:
    
    module NetImap #:nodoc:
      
      module CacheCommandsFix #:nodoc:
        
        def self.included(klass)
          klass.class_eval do
            include InstanceMethods
          end
        end
        
        # Lavabit appears not to like choppy communication, so all outgoing commands
        # are cached first and then released as a coherent string. An exception are
        # Literals, because they require the server to acknowledge their dispatch.
        
        module InstanceMethods
        
          private
          
          def send_command(cmd, *args, &block)
            synchronize do
              tag = Thread.current[:net_imap_tag] = generate_tag
              
              initialize_string_cache_for_delayed_send!
              
              put_string(tag + " " + cmd)
              args.each do |i|
                put_string(" ")
                if i.instance_of?(Net::IMAP::Literal)
                  # the send_literal() method is waiting for a server response
                  # so we need to disable caching for this part
                  release_string_cache_for_delayed_send!
                  send_data(i)
                  initialize_string_cache_for_delayed_send!
                else
                  send_data(i)
                end
              end
              put_string(Net::IMAP::CRLF)
              
              release_string_cache_for_delayed_send!
              
              if cmd == "LOGOUT"
                @logout_command_tag = tag
              end
              if block
                add_response_handler(block)
              end
              begin
                return get_tagged_response(tag)
              ensure
                if block
                  remove_response_handler(block)
                end
              end
            end
          end
          
          def put_string(str)
            unless push_string_cache_for_delayed_send(str)
              @sock.print(str)
              if self.class.debug
                if @debug_output_bol
                  $stderr.print("C: ")
                end
                $stderr.print(str.gsub(/\n(?!\z)/n, "\nC: "))
                if /\r\n\z/n.match(str)
                  @debug_output_bol = true
                else
                  @debug_output_bol = false
                end
              end
            end
          end
          
          # HACK: cache string and eventually release coherently
          
          def initialize_string_cache_for_delayed_send!
            @string_cache_for_delayed_send = ""
          end
          
          def release_string_cache_for_delayed_send!
            cached_string = @string_cache_for_delayed_send
            unless cached_string.nil?
              @string_cache_for_delayed_send = nil
              put_string(cached_string)
            end
          end
          
          def cache_string_for_delayed_send?
            !@string_cache_for_delayed_send.nil?
          end
          
          def push_string_cache_for_delayed_send(str)
            if cache_string_for_delayed_send?
              @string_cache_for_delayed_send << str
              true
            else
              false
            end
          end
        
        end
      
      end
    
    end

  end
  
end
