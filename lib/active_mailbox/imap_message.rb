module ActiveMailbox
  
  class Base
    
    # Turn FetchData responses into Array of ImapMessages.
    
    class MessageListParser
      
      class << self
        
        # Parse a FetchData array.
        
        def read(message_list, conn_id, path, klass, format)
          message_list.collect! { |response|
            attributes = parse_fetchdata(response).merge(:path => path, :format => format)
            klass.instantiate(conn_id, attributes)
          }
        end
        
        private
        
        def parse_fetchdata(response)
          
          message  = response.attr["RFC822"] || response.attr["RFC822.HEADER"]
          envelope = response.attr["ENVELOPE"]
          
          if message.nil? && envelope
            message = parse_envelope(envelope)
          end
          
          flags        = response.attr["FLAGS"]
          internaldate = response.attr["INTERNALDATE"]
          size         = response.attr["RFC822.SIZE"]
          uid          = response.attr["UID"]
          
          { :message => message, :flags => flags, :internaldate => internaldate, :size => size, :uid => uid }
        end
        
        def parse_envelope(envelope)
          message = RMail::Message.new
          
          # a couple of these envelope fiels are supposed NOT to be nil: from, sender, reply_to and date
          # however... guess what! we need to always check. may end up with an empty message, though.
          
          message.header.from     = parse_address(envelope.from)     if (envelope.from)
          message.header.sender   = parse_address(envelope.sender)   if (envelope.sender)
          message.header.reply_to = parse_address(envelope.reply_to) if (envelope.reply_to)
          message.header.to       = parse_address(envelope.to)       if (envelope.to)
          message.header.cc       = parse_address(envelope.cc)       if (envelope.cc)
          message.header.bcc      = parse_address(envelope.bcc)      if (envelope.bcc)
          
          message.header.date           = Time.parse(envelope.date)  if (envelope.date)
          message.header.subject        = envelope.subject           if (envelope.subject)
          message.header["in-reply-to"] = envelope.in_reply_to       if (envelope.in_reply_to)
          message.header["message-id"]  = envelope.message_id        if (envelope.message_id)

          message
        end
        
        def parse_address(addresses)
          addresses.collect { |address|
            rfc822_str = "#{address.mailbox}@#{address.host}"
            # FIXME: does this method handle the route attribute correctly?
            rfc822_str = "#{address.route}:#{rfc822_str}" if (address.route)
            rfc822_str = "#{address.name} <#{rfc822_str}>" if (address.name)
            rfc822_str
          }
        end
        
      end
      
    end
    
    public
    
    # This module is used to create the domain class for IMAP messages. Also see
    # ActiveMailbox::Base::ImapMessage::ClassMethods.
    
    module ImapMessage
      
      # Readable attributes:
      #
      # * <tt>id</tt> - The unique message id.
      # * <tt>internaldate</tt> - The arrival time of the message.
      # * <tt>instance</tt> - The actual RFC822 message.
      # * <tt>format</tt> - Current format (:text, :rmail or :tmail)
      # * <tt>size</tt> - Total size of the RFC822 message in bytes.
      
      ATTR_READER = %w(id internaldate instance format size)
      
      def self.included(klass)  #:nodoc:
        klass.extend(ClassMethods)
        # add attr_reader methods
        ATTR_READER.each { |attr|
          klass.module_eval %{ def #{attr}() @#{attr} end }
        }
      end
      
      # Create a new message object.
      
      def initialize(conn_id, id, message, flags, internaldate, size, path, format = :text)
        super(conn_id)
        self.class.initialize_object(self, id, message, flags, internaldate, size, path, format)
      end
      
      # Compare two message objects.
      
      def ==(m)
       (@conn_id == m.conn_id && @id == m.id) || (self.to_s == m.to_s)
      end
      
      # Retrieve the RFC822 message as string.
      
      def to_s
        if (@instance.is_a?(String))
          @instance
        else
          @instance.to_s
        end
      end
      
      # Convert the RFC822 message to a string.
      
      def to_s!
        @instance = self.to_s
        @format = :text
      end
      
      # Retrieve the RFC822 message as a RMail::Mail object.
      
      def to_rmail
        if (@instance.is_a?(RMail::Message))
          @instance
        else
          RMail::Parser.read(@instance.to_s)
        end
      end
      
      # Convert the RFC822 message to a RMail::Mail object.
      
      def to_rmail!
        @instance = self.to_rmail
        @format = :rmail
      end
      
      # Retrieve the RFC822 message as a TMail::Message object.
      
      def to_tmail
        if (@instance.is_a?(TMail::Mail))
          @instance
        else
          TMail::Mail.parse(@instance.to_s)
        end
      end
      
      # Convert the RFC822 message to a TMail::Message object.
      
      def to_tmail!
        @instance = self.to_tmail
        @format = :tmail
      end
      
      # Retrieve the path of the message.
      
      def path
        @location.path
      end
      
      # Set the path of the message.
      
      def path=(new_path)
        location = self.class.new_location(conn_id, new_path)
        if !location.path.empty?
          @new_location = location
          location_changed!
        end
      end
      
      # Compare the message path to another path.
      
      def path_is?(path)
        location = self.class.new_location(conn_id, path)
        @location.path_is?(location.path)
      end
      
      # Retrieve the message flags.
      
      def flags
        @flags
      end
      
      # Set the message flags.
      
      def flags=(new_flags)
        if !new_flags.nil?
          @flags = new_flags
          flags_changed!
        end
      end
      
      # Retrieve the folder containing this message.
      
      def folder
        if !@conn_id.nil? && !@location.nil?
          self.class.folder_class.find(@conn_id, @location.path)
        else
          []
        end
      end
      
      # Update the path or the flags of the message.
      
      def update(new_path = nil, new_flags = nil)
        self.path = new_path
        self.flags = new_flag
        # TODO: also changes to RFC822 message?
        save!
      end
      
      # Copy the message into another folder.
      
      def duplicate(new_path)
        location = self.class.new_location(conn_id, new_path)
        if !location.path.empty?
          @id = self.class.duplicate(@conn_id, @location.path, @id, :path => location.path)
          @location = location
        end
      end
      
      # Move the message to the trashcan.
      
      def dump!
        if new_record?
          raise Errors::MessageNotFound.new(@id, "Message does only exist locally")
        else
          @id = self.class.dump(@conn_id, @location.path, @id)
          @location = self.class.new_location(conn_id, :Trash)
          @flags << :Deleted
        end
      end
      
      # Permamently remove the message.
      
      def delete!
        if new_record?
          raise Errors::MessageNotFound.new(@id, "Message does only exist locally")
        else
          self.class.delete(@conn_id, @location.path, @id)
          @flags << :Deleted
        end
      end
      
      # Transfer any local changes to this message to the IMAP server.
      
      def save!
        if new_record?
          @id = self.class.create(@conn_id, @location.path, self.to_s, :flags => @flags)
          @changed = []
          @new_record = false
        elsif changed?
          new_path = (location_changed?) ? @new_location.path : nil
          new_flags = (flags_changed?) ? @flags : nil
          
          @id = self.class.update(@conn_id, @location.path, @id, :path => new_path, :flags => new_flags)
          @location = @new_location
          @new_location = nil
          @changed = []
          @new_record = false
        end
        
        self
      end
      
      private
      
      def location_changed!
        if new_record?
          @location = @new_location
          @new_location = nil
        else
          @changed << :location
        end
      end
      
      def flags_changed!
        unless new_record?
          @changed << :flags
        end
      end
      
      public
      
      # ImapMessage class methods. Due to technical limitations, a connection ID and a folder path
      # must be specified each time a specific message is being addressed using class methods. The
      # folder path can be a symbol describing one of the standard folders. For instance:
      #
      #   ImapFolder.find(connection_id, "INBOX", message_id)
      #
      # is equal to
      #
      #   ImapFolder.find(connection_id, :Inbox, message_id)
      
      module ClassMethods
        
        VALID_FIND_OPTIONS    = [ :timeout, :flags, :command, :date, :fetch, :size, :sort_by, :bcc, :body, :cc, :from, :subject, :text, :to, :format, :paginate ]  #:nodoc:
        VALID_CREATE_OPTIONS  = [ :timeout, :flags ]  #:nodoc:
        VALID_COPY_OPTIONS    = [ :timeout, :path ]  #:nodoc:
        VALID_UPDATE_OPTIONS  = [ :timeout, :flags, :mode, :path ]  #:nodoc:
        VALID_DELETE_OPTIONS  = [ :timeout ]  #:nodoc:
        
        GENERIC_FIND_BY = /^find_by_([_a-zA-Z]\w*)$/  #:nodoc:
        GENERIC_FIND_BY_SPECIFIC = /^find_by_(date|flags|size)_([_a-zA-Z]\w*)$/  #:nodoc:
        
        def instantiate(conn_id, attr)  #:nodoc:
          obj = allocate
          obj.instance_variable_set("@conn_id", conn_id)
          initialize_object(obj, attr[:uid], attr[:message], attr[:flags], attr[:internaldate], attr[:size], attr[:path], attr[:format])
        end
        
        def initialize_object(object, id, message, flags, internaldate, size, path, format = :text)  #:nodoc:
          conn_id = object.instance_variable_get("@conn_id")
          
          if (conn_id.nil?)
            raise(ArgumentError, "conn_id can't be NIL")
          end
          
          case format
            when :rmail
              unless message.is_a?(RMail::Message)
                message = (message.is_a?(String)) ? RMail::Parser.read(message) : nil
              end
            when :tmail
              unless message.is_a?(TMail::Mail)
                message = (message.is_a?(String)) ? TMail::Mail.parse(message) : nil
              end
            else
              unless message.is_a?(String)
                message = (message.is_a?(RMail::Message)) ? message.to_s : nil
              end
              format = :text
          end
          
          if message.nil?
            message = ""
            format = :text
          end
          
          if flags.nil?
            flags = []
          end
          
          path = resolve_messagepath_option(conn_id, path)
          
          if path.empty?
            raise(ArgumentError, "path can't be empty (or :Root for that matter)")
          end
          
          location = new_location(conn_id, path)
          
          object.instance_variable_set("@id", id)
          object.instance_variable_set("@instance", message)
          object.instance_variable_set("@flags", flags)
          object.instance_variable_set("@internaldate", internaldate)
          object.instance_variable_set("@size", size)
          object.instance_variable_set("@location", location)
          object.instance_variable_set("@format", format)
          object.instance_variable_set("@changed", [])
          
          object
        end
        
        # Find messages matching your search criteria on a specific connection and within a specific
        # folder. Pass :all as first option to search for any message, or an Integer or an Array of
        # Integers to search for messages with the given ID(s).
        #
        # ==== Options
        #
        # * <tt>:timeout</tt> - Maximum amount of time allowed for this call. Default value is 60 seconds.
        # * <tt>:command</tt> - Invoke a custom SEARCH command if the other options don't satisfy your requirements.
        # * <tt>:fetch</tt> - Which part(s) of the message(s) to fetch. Can be :envelope, :full, :header or anything else for the raw message.
        # * <tt>:sort_by</tt> - Sort messages by passing an Array including one or more of the following symbols: :Arrival, :Cc, :Date, :From, :Reverse, :Size, :Subject or :To. Will raise ActiveMailbox::Errors::ImapCommandNotSupported if the server does not support the SORT command.
        # * <tt>:format</tt> - Convert the RFC822 message to one of the formats :text, :rmail or :tmail
        # * <tt>:paginate</tt> - Paginate the results. Accepts range values.
        #
        # Additionally, there are some options that can be used to specify which messages to include
        # in the search results:
        #
        # * <tt>:flags</tt> - Specifiy message flags by passing a Hash using :Answered, :Deleted, :Draft, :Flagged, :New, :Old, :Recent, :Seen, :Unanswered, :Undeleted, :Undraft, :Unflagged or :Unseen as keys and true/false as values.
        # * <tt>:date</tt> - Specifiy a date for the message(s) by passing a Hash using :Before, :On, :Since, :Sent_before, :Sent_on or :Sent_since as keys and Date objects as values.
        # * <tt>:size</tt> - Specifiy the message size by passing a Hash using :Larger or :Smaller as keys and a Integer objects as values.
        # * <tt>:bcc</tt> - Specify text that should appear within the BCC field of the header.
        # * <tt>:body</tt> - Specify text that should appear within the body of the message.
        # * <tt>:cc</tt> - Specify text that should appear within the CC field of the header.
        # * <tt>:from</tt> - Specify text that should appear within the FROM field of the header.
        # * <tt>:subject</tt> - Specify text that should appear within the SUBJECT field of the header.
        # * <tt>:text</tt> - Specify text that should appear within the header or the body of the message.
        # * <tt>:to</tt> - Specify text that should appear within the TO field of the header.
        
        def find(conn_id, path, *args)
          options = args.extract_options!
          options.assert_valid_keys(VALID_FIND_OPTIONS)
          
          messages = case args.first
          when :all
              find_every(conn_id, path, options)
            else
              ids = extract_ids_from_args(*args)
              find_from_ids(conn_id, path, ids, options)
          end
          
          messages.compact!
          raise Errors::MessageNotFound if messages.empty?
          
          (messages.length > 1) ? messages : messages.first
        end
        
        # Shorthand for find(conn_id, :all, *args) 
        
        def all(conn_id, path, *args)
          find(conn_id, path, :all, *args)
        end
              
        def respond_to?(method_id)  #:nodoc:
          case method_id.to_s
            when GENERIC_FIND_BY
              # includes GENERIC_FIND_BY_SPECIFIC
              return true
          end
          
          super
        end
        
        # Provides a couple of dynamic finder methods in the form of
        #
        #   find_by_{search_option}
        #
        # and the more specific variants
        #
        #   find_by_date_{date_option}
        #   find_by_flags_{flag_option}
        #   find_by_size_{size_option}
        #
        # where +search_option+ may be anything of the search params specified for the <tt>find</tt>
        # method. For instance:
        # 
        #   ImapMessage.find_by_flags(connection_id, :Inbox, :Deleted => false)
        #   ImapMessage.find_by_subject(connection_id, :Trash, "Re: Party tonight!")
        #   ImapMessage.find_by_size(connection_id, :Sent, :Larger => 2.kilobytes)
        # 
        # The specific variants allow even more compact versions of some of these dynamic finders:
        #
        #   ImapMessage.find_by_flags_deleted(connection_id, :Inbox, false)
        #   ImapMessage.find_by_size_larger(connection_id, :Sent, 2.kilobytes)
        
        def method_missing(method_id, *args, &block)
          case method_id.to_s
            when GENERIC_FIND_BY_SPECIFIC
              conn_id = args.shift
              path    = args.shift
              
              options = resolve_generic_find_option($1.to_sym, $2.capitalize.to_sym, *args)
              return find(conn_id, path, :all, options)
            when GENERIC_FIND_BY
              conn_id = args.shift
              path    = args.shift
              
              options = resolve_generic_find_option($1.to_sym, nil, *args)
              return find(conn_id, path, :all, options)
          end
          
          super
        end
        
        # Check whether a specific message exists. The same rules as for the <tt>find</tt> method apply.
        
        def exists?(conn_id, path, *args)
          options = args.extract_options!
          options.assert_valid_keys(VALID_FIND_OPTIONS)
          
          case args.first
            when :all
              check_every(conn_id, path, options)
            else
              ids = extract_ids_from_args(*args)
              check_by_ids(conn_id, path, ids, options)
          end
        end
        
        # Create a new message underneath a specific path.
        #
        # ==== Options
        #
        # * <tt>:timeout</tt> - Maximum amount of time allowed for this call. Default value is 40 seconds.
        # * <tt>:flags</tt> - Message flags.
        
        def create(conn_id, path, message, *args)
          options = args.extract_options!
          options.assert_valid_keys(VALID_CREATE_OPTIONS)
          
          timeout = resolve_timeout_option(options[:timeout], 40.seconds)
          path    = resolve_messagepath_option(conn_id, path)
          
          with_connection(conn_id, timeout) { |conn|
            conn.message_create(path, message, options[:flags])
          }
        end
        
        # Copy a message to a specific path.
        #
        # ==== Options
        #
        # * <tt>:timeout</tt> - Maximum amount of time allowed for this call. Default value is 40 seconds.
        # * <tt>:path</tt> - The path to copy the message to.
        
        def duplicate(conn_id, path, *args)
          options = args.extract_options!
          options.assert_valid_keys(VALID_COPY_OPTIONS)
          
          ids = extract_ids_from_args(*args)
          timeout = resolve_timeout_option(options[:timeout], 20.seconds)
          source  = resolve_messagepath_option(conn_id, path)
          target  = resolve_messagepath_option(conn_id, options[:path])
          
          with_connection(conn_id, timeout) { |conn|
            conn.message_duplicate(source, target, ids)
          }
        end
        
        # Update a message.
        #
        # ==== Options
        #
        # * <tt>:timeout</tt> - Maximum amount of time allowed for this call. Default value is 20 seconds.
        # * <tt>:flags</tt> - Message flags.
        # * <tt>:mode</tt> - How to handle the <tt>:flags</tt> option (:set, :add, :delete)
        # * <tt>:path</tt> - New path for the message.
        
        def update(conn_id, path, id, *args)
          options = args.extract_options!
          options.assert_valid_keys(VALID_UPDATE_OPTIONS)
          
          default_options = { :mode => :set }
          options.reverse_merge!(default_options)
          
          timeout  = resolve_timeout_option(options[:timeout], 20.seconds)
          path     = resolve_messagepath_option(conn_id, path)
          new_path = resolve_messagepath_option(conn_id, options[:path])
          
          with_connection(conn_id, timeout) { |conn|
            conn.message_update(path, new_path, id, options[:flags], options[:mode])
          }
        end
        
        # Permamently remove a message.
        #
        # ==== Options
        #
        # * <tt>:timeout</tt> - Maximum amount of time allowed for this call. Default value is 10 seconds.
        
        def delete(conn_id, path, id, *args)
          options = args.extract_options!
          options.assert_valid_keys(VALID_DELETE_OPTIONS)
          
          timeout = resolve_timeout_option(options[:timeout], 10.seconds)
          path    = resolve_messagepath_option(conn_id, path)
          
          with_connection(conn_id, timeout) { |conn|
            conn.message_delete(path, id, false)
          }
        end
        
        # Move a message to the trashcan.
        #
        # ==== Options
        #
        # * <tt>:timeout</tt> - Maximum amount of time allowed for this call. Default value is 10 seconds.
        
        def dump(conn_id, path, id, *args)
          options = args.extract_options!
          options.assert_valid_keys(VALID_DELETE_OPTIONS)
          
          timeout = resolve_timeout_option(options[:timeout], 10.seconds)
          path    = resolve_messagepath_option(conn_id, path)
          
          with_connection(conn_id, timeout) { |conn|
            conn.message_delete(path, id, true)
          }
        end
        
        private
        
        def extract_ids_from_args(*args)
          ids = args.first
          ids = (ids.is_a?(Array)) ? ids.flatten.compact.uniq : [ids]
          raise(ArgumentError, "Couldn't find message without an ID") if ids.empty?
          ids
        end
        
        def find_every(conn_id, path, options)
          timeout = resolve_timeout_option(options[:timeout], 60.seconds)
          path    = resolve_messagepath_option(conn_id, path)
          
          search_command = resolve_search_option(options)
          fetch_command  = resolve_fetch_option(options)
          sort_command   = resolve_sort_option(options)
          format         = resolve_format_option(options[:format])
          paginate       = resolve_paginate_option(options[:paginate])
          
          message_list = with_connection(conn_id, timeout) { |conn|
            conn.message_retrieve(path, search_command, fetch_command, sort_command, paginate)
          }
          
          MessageListParser.read(message_list, conn_id, path, self, format)
        end
        
        def find_from_ids(conn_id, path, ids, options)
          unless options.is_a?(Hash) && (options[:command].nil? || options[:command].is_a?(Array))
            raise(ArgumentError, "Bad options format (expected Hash with :command key that is either NIL or an Array)")
          end
          
          options[:command] = resolve_command_option(options[:command], ids)
          
          find_every(conn_id, path, options)
        end
        
        def check_every(conn_id, path, options)
          timeout = resolve_timeout_option(options[:timeout], 10.seconds)
          path    = resolve_messagepath_option(conn_id, path)
          
          search_command = resolve_search_option(options)
          
          with_connection(conn_id, timeout) { |conn|
            conn.message_exists?(path, search_command)
          }
        end
        
        def check_by_ids(conn_id, path, ids, options)
          unless options.is_a?(Hash) && (options[:command].nil? || options[:command].is_a?(Array))
            raise(ArgumentError, "Bad options format (expected Hash with :command key that is either NIL or an Array)")
          end
          
          options[:command] = resolve_command_option(options[:command], ids)
          
          check_every(conn_id, path, options)
        end
        
      end
    
    end
    
  end
  
end