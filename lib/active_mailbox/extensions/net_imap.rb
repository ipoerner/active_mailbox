Dir.glob(File.join(File.dirname(__FILE__), 'net_imap/*_imap.rb')).each {|f| require f }

module ActiveMailbox
  
  module Extensions #:nodoc:
    
    #
    # General extensions to the Net::IMAP class
    #
    
    module NetImap
      
      module RaceConditionFix #:nodoc:
        
        def self.included(klass)
          klass.class_eval do
#            remove_method :capability
#            remove_method :select
#            remove_method :examine
            remove_method :list
#            remove_method :getquotaroot
#            remove_method :getquota
#            remove_method :getacl
#            remove_method :lsub
#            remove_method :status
#            remove_method :expunge
            
#            remove_method :search_internal
#            remove_method :fetch_internal
#            remove_method :store_internal
#            remove_method :sort_internal
            
            # removing method 'initialize' yields a warning and is also a pretty nasty thing to
            # do when using modules
            
            alias_method :init_original, :initialize
            
            def initialize(host, port = PORT, usessl = false, certs = nil, verify = false)
              @commands = Hash.new(false).extend(Mutex_m)
              @command_queue = new_cond
              init_original(host, port, usessl, certs, verify)
            end
            
            include InstanceMethods
          end
        end
        
        #
        # There's a possible race condition when using Net::IMAP for concurrent calls
        # that invoke the same type of command, but only if that call awaits one or more
        # untagged responses.
        #
        # For instance:
        #
        #   conn = Net::IMAP.new ("imap.example.com")
        #
        #   100. times do
        #     Thread.new { conn.capability }
        #   end
        #
        # This program will most probably yield an <tt>undefined method</tt> error once the
        # <tt>capability</tt> method attempts to access a NIL value in the </tt>@responses</tt> Hash.
        # This occurs after another thread has read and ultimately removed the expected value.
        #
        # The solution is to only allow concurrent calls for distinct commands, and put them into a
        # queue incase the command has been invoked already.
        #
        
        module InstanceMethods
          
          private
          
          def begin_command(cmd)
            @command_queue.wait_while { @commands[cmd] }
            @commands[cmd] = true
          end
      
          def end_command(cmd)
            @commands.delete(cmd)
            @command_queue.signal
          end
      
          def cmd_synchronize(cmd, &block)
            synchronize do
              begin_command(cmd)
              result = yield
              end_command(cmd)
              result
            end
          end
          
          public
          
          def capability #:nodoc:
            cmd_synchronize("CAPABILITY") do
              send_command("CAPABILITY")
              @responses.delete("CAPABILITY")[-1]
            end
          end
          
          def select(mailbox) #:nodoc:
            cmd_synchronize("SELECT") do
              @responses.clear
              send_command("SELECT", mailbox)
            end
          end
          
          def examine(mailbox) #:nodoc:
            cmd_synchronize("EXAMINE") do
              @responses.clear
              send_command("EXAMINE", mailbox)
            end
          end
          
          def list(refname, mailbox) #:nodoc:
            cmd_synchronize("LIST") do
              send_command("LIST", refname, mailbox)
              @responses.delete("LIST")
            end
          end
          
          def getquotaroot(mailbox) #:nodoc:
            cmd_synchronize("GETQUOTA") do
              send_command("GETQUOTAROOT", mailbox)
              result = []
              result.concat(@responses.delete("QUOTAROOT"))
              result.concat(@responses.delete("QUOTA"))
              result
            end
          end
          
          def getquota(mailbox) #:nodoc:
            cmd_synchronize("GETQUOTA") do
              send_command("GETQUOTA", mailbox)
              @responses.delete("QUOTA")
            end
          end
          
          def getacl(mailbox) #:nodoc:
            cmd_synchronize("ACL") do
              send_command("GETACL", mailbox)
              @responses.delete("ACL")[-1]
            end
          end
          
          def lsub(refname, mailbox) #:nodoc:
            cmd_synchronize("LSUB") do
              send_command("LSUB", refname, mailbox)
              @responses.delete("LSUB")
            end
          end
          
          def status(mailbox, attr) #:nodoc:
            cmd_synchronize("STATUS") do
              send_command("STATUS", mailbox, attr)
              @responses.delete("STATUS")[-1].attr
            end
          end
          
          def expunge #:nodoc:
            cmd_synchronize("EXPUNGE") do
              send_command("EXPUNGE")
              @responses.delete("EXPUNGE")
            end
          end
          
          private
          
          def search_internal(cmd, keys, charset)
            if keys.instance_of?(String)
              keys = [Net::IMAP::RawData.new(keys)]
            else
              normalize_searching_criteria(keys)
            end
            cmd_synchronize("SEARCH") do
              if charset
                send_command(cmd, "CHARSET", charset, *keys)
              else
                send_command(cmd, *keys)
              end
              @responses.delete("SEARCH")[-1]
            end
          end
      
          def fetch_internal(cmd, set, attr)
            if attr.instance_of?(String)
              attr = Net::IMAP::RawData.new(attr)
            end
            cmd_synchronize("FETCH") do
              @responses.delete("FETCH")
              send_command(cmd, Net::IMAP::MessageSet.new(set), attr)
              @responses.delete("FETCH")
            end
          end
      
          def store_internal(cmd, set, attr, flags)
            if attr.instance_of?(String)
              attr = Net::IMAP::RawData.new(attr)
            end
            cmd_synchronize("FETCH") do
              @responses.delete("FETCH")
              send_command(cmd, Net::IMAP::MessageSet.new(set), attr, flags)
              @responses.delete("FETCH")
            end
          end
      
          def sort_internal(cmd, sort_keys, search_keys, charset)
            if search_keys.instance_of?(String)
              search_keys = [Net::IMAP::RawData.new(search_keys)]
            else
              normalize_searching_criteria(search_keys)
            end
            normalize_searching_criteria(search_keys)
            cmd_synchronize("SORT") do
              send_command(cmd, sort_keys, charset, *search_keys)
              @responses.delete("SORT")[-1]
            end
          end
          
        end
        
      end

      module Messages #:nodoc:
        
        def self.included(klass)
          klass.class_eval do
            include InstanceMethods
          end
        end
        
        # Easy access to server BYE, CAPABILITY and GREETING responses.
        
        module InstanceMethods
          
          # Retrieve server capabilities from the servers welcome message or the CAPABILITY response.
          # 
          # BE AWARE THAT THIS FEATURE REMAINS DISABLED AS MANY SERVERS APPEAR TO INCLUDE
          # DIFFERENT CAPABILITY VALUES IN THE GREETING RESPONSE!
          
          def capabilities
            if false
              unless @greeting.nil? || (greeting_code = @greeting.data.code).nil?
                # some servers include capability response in greeting message
                return greeting_code.data.split if (greeting_code.name == "CAPABILITY")
              end
            end
            capability
          end
          
          # Retrieve server greeting response.
          
          def greeting_response
            unless @greeting.nil?
              @greeting.data.text
            end
          end
          
          # Retrieve server BYE response.
          
          def bye_response
            unless @responses["BYE"].nil?
              @responses["BYE"].first.text
            end
          end
        
        end
        
      end
      
      module FetchMacros #:nodoc:
        
        def self.included(klass)
          klass.class_eval do
            remove_method :fetch
            remove_method :uid_fetch
            include InstanceMethods
          end
        end
        
        # Manual implementation of the FETCH macros 'ALL', 'FAST' and 'FULL'.
        
        module InstanceMethods
        
          FETCH_MACROS = { "FAST" => %w(FLAGS INTERNALDATE RFC822.SIZE),
                           "ALL"  => %w(FLAGS INTERNALDATE RFC822.SIZE ENVELOPE),
                           "FULL" => %w(FLAGS INTERNALDATE RFC822.SIZE ENVELOPE BODY)
          } #:nodoc:
          
          def fetch(set, attr) #:nodoc:
            attr = filter_macros(attr)
            fetch_internal("FETCH", set, attr) || []
          end
          
          def uid_fetch(set, attr) #:nodoc:
            attr = filter_macros(attr)
            fetch_internal("UID FETCH", set, attr) || []
          end
          
          private
          
          def filter_macros(attr)
            if !attr.instance_of?(Array)
              attr = Array.new(1,attr)
            end
            attr.each do |a|
              macro = FETCH_MACROS[a.upcase]
              return macro unless macro.nil?
            end
            attr
          end
      
        end
      
      end
      
      module SearchInternalFix #:nodoc:
        
        def self.included(klass)
          klass.class_eval do
            #remove_method :search_internal
            include InstanceMethods
          end
        end
        
        # Fix for servers that don't send anything when SEARCH yields no results.
        
        module InstanceMethods
          
          private
          
          def search_internal(cmd, keys, charset)
            if keys.instance_of?(String)
              keys = [Net::IMAP::RawData.new(keys)]
            else
              normalize_searching_criteria(keys)
            end
            cmd_synchronize("SEARCH") do
              if charset
                send_command(cmd, "CHARSET", charset, *keys)
              else
                send_command(cmd, *keys)
              end
              result = @responses.delete("SEARCH")
              (result.instance_of?(Array)) ? result.flatten.compact : result
            end
          end
        
        end
        
      end
      
      module Unselect #:nodoc:
        
        def self.included(klass)
          klass.class_eval do
            include InstanceMethods
          end
        end
        
        # Implements the UNSELECT command.
        
        module InstanceMethods
          
          # Unselect currently selected folder.
          
          def unselect
            send_command("UNSELECT")
          end
        
        end
        
      end
      
      module NoByeResponseFix #:nodoc:
        
        def self.included(klass)
          klass.class_eval do
            remove_method :response_untagged
            include InstanceMethods
          end
        end
        
        # Fix for servers that do not send a BYE response text
        
        module InstanceMethods
        
          private
          
          def response_untagged
            match(Net::IMAP::ResponseParser::T_STAR)
            match(Net::IMAP::ResponseParser::T_SPACE)
            token = lookahead
            if token.symbol == Net::IMAP::ResponseParser::T_NUMBER
              return numeric_response
            elsif token.symbol == Net::IMAP::ResponseParser::T_ATOM
              case token.value
                when /\A(?:OK|NO|BAD|PREAUTH)\z/ni
                return response_cond
                when /\A(?:BYE)\z/ni
                return bye_response
                when /\A(?:FLAGS)\z/ni
                return flags_response
                when /\A(?:LIST|LSUB)\z/ni
                return list_response
                when /\A(?:QUOTA)\z/ni
                return getquota_response
                when /\A(?:QUOTAROOT)\z/ni
                return getquotaroot_response
                when /\A(?:ACL)\z/ni
                return getacl_response
                when /\A(?:SEARCH|SORT)\z/ni
                return search_response
                when /\A(?:THREAD)\z/ni
                return thread_response
                when /\A(?:STATUS)\z/ni
                return status_response
                when /\A(?:CAPABILITY)\z/ni
                return capability_response
              else
                return text_response
              end
            else
              parse_error("unexpected token %s", token.symbol)
            end
          end
          
          def bye_response
            token = match(Net::IMAP::ResponseParser::T_ATOM)
            name = token.value.upcase
            # do not match T_SPACE as T_CRLF/T_EOF will follow immediately
            return Net::IMAP::UntaggedResponse.new(name, resp_text, @str)
          end
        
        end
        
      end
      
    end
    
  end
  
end

if RUBY_VERSION < "1.9"
  
  module Net
    
    class IMAP
      
      #
      # PLAIN authenticator, not included in Ruby versions prior to 1.9
      #
      
      class Net::IMAP::PlainAuthenticator
        
        def process(data)
          return "\0#{@user}\0#{@password}"
        end
        
        private 
        
        def initialize(user, password)
          @user = user
          @password = password
        end
        
      end
      
      add_authenticator('PLAIN', PlainAuthenticator)
      
    end
    
  end
  
end