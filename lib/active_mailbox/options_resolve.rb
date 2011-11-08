module ActiveMailbox
  
  class Base
  
    module BaseOptionsResolve  #:nodoc:
      
      VALID_STANDARD_FOLDERS = [ :Inbox, :Trash, :Drafts, :Sent, :Root ]
      
      def resolve_timeout_option(timeout, default = nil)
       (timeout.is_a?(ActiveSupport::Duration) || timeout.is_a?(Numeric)) ? timeout : default
      end
      
      def resolve_path_option(conn_id, path, default = nil)
        path ||= default
        
        if VALID_STANDARD_FOLDERS.include?(path)
          path = base_class.standard_folder(conn_id, path)
        end
        
        raise(ArgumentError, "Invalid path: #{path}") unless path.is_a?(String)
        path
      end
      
    end
    
    module FolderOptionsResolve  #:nodoc:
      
      VALID_FILTER_OPTIONS = [ :subscribed, :noinferiors, :noselect, :marked, :unmarked ]
      
      def resolve_folderpath_option(conn_id, folder)
        resolve_path_option(conn_id, folder, :Root)
      end
      
      def resolve_subscription_option(subscription)
       (subscription == true) ? subscription : false
      end
      
      def resolve_attributes_option(options)
        if options.is_a?(Hash)
          include_attr = []
          exclude_attr = []
          
          if (attributes = options.delete(:attributes)).is_a?(Hash)
            attributes.each_key do |key, value|
              if VALID_FILTER_OPTIONS.include?(key)
                attr = key.to_s.capitalize.to_sym
                if value
                  include_attr << attr
                else
                  exclude_attr << attr
                end
              end
            end
          end
          
          options[:include] = include_attr
          options[:exclude] = exclude_attr
        end
        
        options
      end
      
    end
    
    module MessageOptionsResolve  #:nodoc:
      
      def resolve_messagepath_option(conn_id, folder)
        resolve_path_option(conn_id, folder, :Inbox)
      end
      
      VALID_FORMAT_OPTIONS = [:rmail, :tmail, :text]
      
      VALID_DATE_OPTIONS = [:Before, :On, :Since, :Sent_before, :Sent_on, :Sent_since]
      VALID_FLAG_OPTIONS = [:Answered, :Deleted, :Draft, :Flagged, :New, :Old, :Recent, :Seen, :Unanswered, :Undeleted, :Undraft, :Unflagged, :Unseen]
      VALID_SIZE_OPTIONS = [:Larger, :Smaller]
      
      VALID_TEXT_OPTIONS = [:bcc, :body, :cc, :from, :subject, :text, :to]

      VALID_SORT_OPTIONS = [:Arrival, :Cc, :Date, :From, :Reverse, :Size, :Subject, :To]
      VALID_GENERIC_FIND_OPTIONS = { :date => VALID_DATE_OPTIONS, :flags => VALID_FLAG_OPTIONS, :size => VALID_SIZE_OPTIONS }
      
      def resolve_paginate_option(paginate)
        (paginate.is_a?(Range)) ? paginate : nil
      end
      
      def resolve_format_option(format)
        if VALID_FORMAT_OPTIONS.include?(format)
          format
        else
          :text
        end
      end
      
      def resolve_generic_find_option(find_by, specific, *args)
        find_what = args.shift
        options = args.extract_options!
        
        if VALID_GENERIC_FIND_OPTIONS.has_key?(find_by)
          if specific.nil?
            options[find_by] = find_what
          elsif VALID_GENERIC_FIND_OPTIONS[find_by].include?(specific)
            options[find_by] = { specific => find_what }
          end
        elsif VALID_TEXT_OPTIONS.include?(find_by)
          options[find_by] = find_what
        end
        
        options
      end
      
      def resolve_date_option(date)
        command = []
        
        if date.is_a?(Hash)
          date.assert_valid_keys(VALID_DATE_OPTIONS)
          
          date.each do | key, value |
            next unless value.is_a?(Date)
            # need to convert these keys
            case key
              when :Sent_before
              key = "SENTBEFORE"
              when :Sent_on
              key = "SENTON"
              when :Sent_since
              key = "SENTSINCE"
            end
            
            command << key.to_s.upcase
            command << value.to_s
          end
        end
        
        (command.empty?) ? nil : command
      end
      
      def resolve_flags_option(flags)
        command = []
        
        if flags.is_a?(Hash)
          flags.assert_valid_keys(VALID_FLAG_OPTIONS)
          
          flags.each do | key, value |
            command << "NOT" if (value == false)
            command << key.to_s.upcase
          end
        end
        
        if !flags.is_a?(Hash) || !(flags.include?(:Deleted) || flags.include?(:Undeleted))
          command << "NOT"
          command << "DELETED"
        end
        
        (command.empty?) ? nil : command
      end
      
      def resolve_size_option(size)
        command = []
        
        if size.is_a?(Hash)
          size.assert_valid_keys(VALID_SIZE_OPTIONS)
          
          size.each do | key, value |
            next unless value.is_a?(Integer)
            command << key.to_s.upcase
            command << value.to_s
          end
        end
        
        (command.empty?) ? nil : command
      end
      
      def resolve_text_option(options)
        command = []
        
        if options.is_a?(Hash)
          options.each do | key, value |
            if VALID_TEXT_OPTIONS.include?(key) && value.is_a?(String)
              command << key.to_s.upcase
              command << value
            end
          end
        end
        
        (command.empty?) ? nil : command
      end
      
      def resolve_search_option(options)
        unless options.is_a?(Hash) && (options[:command].nil? || options[:command].is_a?(Array))
          raise(ArgumentError, "Bad options format (expected Hash with :command key that is either NIL or an Array)")
        end
        
        command = options[:command] || ["ALL"]
        command << resolve_date_option(options[:date])
        command << resolve_flags_option(options[:flags])
        command << resolve_size_option(options[:size])
        command << resolve_text_option(options)
        command.flatten.compact
      end
      
      #
      # Use pre-defined filters to generate keys for the FETCH command, so that
      # it is assured that the parser can handle the generated response.
      #
      
      def resolve_fetch_option(options)
        command = case options[:fetch]
          when :envelope
            ["FLAGS", "INTERNALDATE", "RFC822.SIZE", "ENVELOPE"]
          when :full
            ["FLAGS", "INTERNALDATE", "RFC822.SIZE", "RFC822"]
          when :header
            ["RFC822.HEADER"]
        else
          ["RFC822"]
        end
        
        # always fetch UID for message
        command << "UID"
      end
      
      def resolve_sort_option(options)
        command = Array.new
        
        if options[:sort_by].is_a?(Array)
          options.each do |o|
            raise(ArgumentError, "Invalid key: #{o}") unless VALID_SORT_OPTIONS.include?(o)
          end
          
          command = options[:sort_by].collect { |o| o.to_s.upcase }
        end
        
        command
      end
      
      def resolve_command_option(command, ids)
        command = Array.new unless command.is_a?(Array)
        command << "UID"
        command << ids.join(",")
      end
      
    end
    
  end
  
end