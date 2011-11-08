module ActiveMailbox
  
  module ConnectionAdapters
    
    ListCommand = Struct.new(:reference, :wildcards)
    
    # This module mixes the Generic, Messages, Folders and Capabilities modules into an existing class.
    
    module ImapStatements
      
      def self.included(klass)
        klass.class_eval do
          include Generic
          include Messages
          include Folders
          include Capabilities
        end
      end
      
      # Wrap most of the IMAP commands as provided by the Net::IMAP library. Some calls like
      # suscribe/unsubscribe are merged into a single method, a couple of others are preceded
      # with some additional conditions.
      
      module Generic
        
        protected
        
        # Send a NOOP command to the server (may come handy if the client needs to leave the server some time).
        
        def noop
          @connection.noop
        end
        
        # Select a folder if the folder has not been selected already.
        
        def select(folder, force_select = false)
          if !folder.nil? && (force_select || folder != @selected)
            @selected = nil
            @connection.select(folder)
            @selected = folder
          end
          @selected
        end
        
        # Unselect a folder.
        
        def unselect(force_unselect = false)
          if !@selected.nil? || force_unselect
            @selected = nil
            if supports_unselect?
              @connection.unselect
            else
              begin
                # hack: selecting an apparently invalid path
                @connection.select("/////.....")
              rescue Net::IMAP::NoResponseError
              end
            end
          end
        end
        
        # Examine a folder (the folder is not selected but the server response is the same).
        
        def examine(folder)
          @selected = nil
          @connection.examine(folder) unless folder.nil?
        end
        
        # Retrieve the full status of a folder (total number of messages, number of recent messages, number of unseen messages).
        
        def status(folder)
          @connection.status(folder, ["MESSAGES", "RECENT", "UNSEEN"])
        end
        
        # Expunge messages from a folder.
        
        def expunge!
          @connection.expunge
        end
        
        # Get a list of folders from the server (regardless of subscription status). Will always return
        # an empty array incase the result is NIL.
        
        def list(reference, wildcards)
          @connection.list(reference, wildcards) || []
        end
        
        # Get a list of subscribed folders from the server. Will always return an empty array incase
        # the result is NIL.
        #
        
        def lsub(reference, wildcards)
          @connection.lsub(reference, wildcards) || []
        end
        
        # Create a folder under a given path.
        
        def create(path)
          @connection.create(path)
        end
        
        # Rename a folder.
        
        def rename(path, new_path)
          unselect
          @connection.rename(path, new_path)
        end
        
        # Delete a folder permamently.
        
        def delete(path)
          unselect
          @connection.delete(path)
        end
        
        # Get subscription status of a folder.
        
        def folder_is_subscribed?(path)
          folders_contain?(lsub("", "*"), path)
        end
        
        # check whether a folder exists.
        
        def folder_exists?(path)
          folders_contain?(list("", "*"), path)
        end
        
        # Subscribe a folder incase it's not subscribed already.
        
        def subscribe(path, subscription)
          if folder_exists?(path)
            if (subscription != folder_is_subscribed?(path))
              if (subscription)
                @connection.subscribe(path)
              else
                @connection.unsubscribe(path)
              end
            end
          end
        end
        
        # Search for message UIDs.
        
        def uid_search(folder, search_keys, sort_by)
          select(folder)
          @connection.check
          
          unless search_keys.nil? || search_keys.empty?
            if sort_by && !sort_by.empty? && supports_sort?
              return @connection.uid_sort(sort_by, search_keys, "US-ASCII")
            else
              return @connection.uid_search(search_keys)
            end
          end
          
          return []
        end
        
        # Get messages (or part(s) of messages) from a list of UIDs.
        
        def uid_fetch(folder, uid_list, fetch_keys)
          select(folder)
          @connection.check
          
          uid_list = [uid_list] unless uid_list.is_a?(Array)
          fetch_keys = [fetch_keys] unless fetch_keys.is_a?(Array)
          
          unless uid_list.empty? || fetch_keys.empty?
            return @connection.uid_fetch(uid_list, fetch_keys)
          end
          
          return []
        end
        
        # Append a message to a folder.
        
        def append(folder, message, flags = nil)
          unselect
          
          unless message.is_a?(RMail::Message)
            message = RMail::Parser.read(message)
          end
          
          uid = if message_tagging_enabled?
            checksum = KeyGenerator.sha2_hash
            message.prepare_for_append(checksum)
            @connection.append(folder, message.to_s, filter_flags(flags))
            get_uid_from_checksum(folder, checksum)
          else
            message.prepare_for_append
            response = @connection.append(folder, message.to_s, filter_flags(flags))
            get_uid_from_response(response, "APPENDUID")
          end
          
          uid
        end
        
        # Move a message to another folder. The old message will receive the /Deleted flag.
        
        def uid_move(source, target, uid)
          new_uid = uid_copy(source, target, uid)
          mark_deleted(source, uid)
          new_uid
        end
        
        # Copy a message to another folder.
        
        def uid_copy(source, target, uid)
          select(source)
          
          new_uid = if message_tagging_enabled?
            @connection.check
            message = uid_fetch(source, uid, ["FLAGS", "RFC822"]).first
            append(target, message.attr["RFC822"], message.attr["FLAGS"])
          else
            response = @connection.uid_copy(uid, target)
            get_uid_from_response(response, "COPYUID")
          end
          
          new_uid.to_i
        end
        
        # Change message flags.
        
        def change_flags(folder, uid, flags, mode = :set)
          flags = filter_flags(flags)
          if (uid > 0 && !flags.nil?)
            select(folder)
            case mode
              when :add
              @connection.uid_store(uid, "+FLAGS", flags)
              when :delete
              @connection.uid_store(uid, "-FLAGS", flags)
            else
              @connection.uid_store(uid,  "FLAGS", flags)
            end
          end
        end
        
        # Add the /Deleted flag to a message.
        
        def mark_deleted(folder, uid)
          select(folder)
          @connection.uid_store(uid, "+FLAGS", :Deleted)
        end
        
        private
        
        def filter_flags(flags)
          unless flags.nil?
            # /Recent is a system flag that is not allowed to change
            flags.delete_if { |f| f == :Recent }
            flags = nil if flags.empty?
          end
          flags
        end
        
        def get_uid_from_response(response, codename)
          uid = nil
          
          unless response.nil? || response.data.nil?
            code = response.data.code
            if response.name == "OK" && !code.nil? && code.name == codename
              uid = code.data.split.last
            end
          end
          
          uid
        end
        
        def get_uid_from_checksum(folder, checksum)
          uid_list = uid_search(folder, "ALL", false)
          messages = uid_fetch(folder, uid_list, ["UID", "RFC822.HEADER"])
          
          messages.each { |msg|
            # parsing to RMail::Message makes life a lot easier, as header fields may
            # spread over several lines
            message = RMail::Parser.read(msg.attr["RFC822.HEADER"])
            
            if (message.checksum == checksum)
              return msg.attr["UID"].to_i
            end
          }
          
          nil
        end
  
      end
      
      # Implement IMAP calls required to interact with messages.
      
      module Messages
        
        include Generic
        
        SEARCH_TOKENS = %w(ALL ANSWERED BCC BEFORE BODY CC DELETED DRAFT FLAGGED FROM
                           HEADER KEYWORD LARGER NEW NOT OLD ON OR RECENT SEEN SENTBEFORE
                           SENTON SENTSINCE SINCE SMALLER SUBJECT TEXT TO UID UNANSWERED
                           UNDELETED UNDRAFT UNFLAGGED UNKEYWORD UNSEEN)  #:nodoc:
        
        SEARCH_TOKENS_REGEX = /^([a-zA-Z]|[0-9]+((,[0-9]+)|(:[0-9]+))*)+$/  #:nodoc:
        
        FETCH_TOKENS = %w(ALL FAST FULL BODY BODY.PEEK BODYSTRUCTURE ENVELOPE FLAGS
                          INTERNALDATE RFC822 RFC822.HEADER RFC822.SIZE RFC822.TEXT UID)  #:nodoc:
        
        FETCH_TOKENS_REGEX = /^([a-zA-Z]+[\w]*(\.[a-zA-Z]+)*)+$/  #:nodoc:
        
        SORT_TOKENS = %w(ARRIVAL CC DATE FROM REVERSE SIZE SUBJECT TO)  #:nodoc:
        
        SORT_TOKENS_REGEX = /^[a-zA-Z]+$/  #:nodoc:
        
        # Retrieve messages from a folder.
        
        def message_retrieve(folder, search_keys, fetch_keys, sort_by, paginate)
          
          message_list = []
          
          raise(Errors::ImapCommandNotSupported, "SORT") if (sort_by && !sort_by.empty? && !supports_sort?)
          
          # filter invalid fetch criterias
          fetch_keys.delete_if do |fk|
            !(fk =~ FETCH_TOKENS_REGEX) || !FETCH_TOKENS.include?($~[0].upcase.to_s)
          end
          
          # filter invalid sort criteria
          if !(sort_by =~ SORT_TOKENS_REGEX) || !SORT_TOKENS.include?($~[0].upcase.to_s)
            sort_by = []
          end
          
          @rwlock.read {
            uid_list = uid_search(folder, search_keys, sort_by)
            uid_list = uid_list[paginate] unless paginate.nil?
            message_list = uid_fetch(folder, uid_list, fetch_keys)
          }
          
          message_list
        end
        
        # Check whether specific messages exist in a folder.
         
        def message_exists?(folder, search_keys)
          uid_list = []
          
          @rwlock.read {
            uid_list = uid_search(folder, search_keys, false)
          }
          
          !uid_list.empty?
        end
        
        # Add a new message to a folder.
        
        def message_create(folder, message, flags)
          folder = @selected if folder.nil?
          
          uid = @rwlock.write {
            append(folder, message, flags)
          }
          
          uid.to_i
        end
        
        # Copy a message to the trashcan, set /Deleted flag.
        
        def message_delete(folder, uid, dump = true)
          trashcan = standard_folder(:Trash)
          
          if folder == trashcan
            dump = false 
          end
          
          @rwlock.write {
            if dump
              new_uid = uid_copy(folder, trashcan, uid)
              mark_deleted(folder, uid)
              mark_deleted(trashcan, new_uid)
              uid = new_uid
            else
              mark_deleted(folder, uid)
            end
          }
          
          uid.to_i
        end
        
        # Duplicate a message.
        
        def message_duplicate(source, target, uid_list)
          uid = uid_copy(source, target, uid_list)
          uid.to_i
        end
        
        # Update messages (move to different folder or set message flags).
        
        def message_update(folder, target, uid, flags, mode)
          do_move = !(folder == target) && !target.nil?
          do_change_flags = !(flags.nil? || (flags.instance_of?(Array) && flags.empty?))
          
          return unless (do_move || do_change_flags)
          
          @rwlock.write {
            if (do_move)
              uid = uid_move(folder, target, uid)
            end
            
            if (do_change_flags)
              change_flags(target, uid, flags, mode)
            end
          }
          
          uid.to_i
        end
        
      end
      
      # Implement IMAP calls required to interact with folders.
      
      module Folders
        
        include Generic
        
        # Retrieve folders.
        
        def folder_retrieve(command, include_attr = nil, exclude_attr = nil)
          
          folder_list = []
          subscribed_list = []
          
          @rwlock.read {
            folder_list     = list(command.reference, command.wildcards)
            subscribed_list = lsub(command.reference, command.wildcards)
          }
          
          # add :Subscribed flag to folders in the subscribed list
          folder_list.each do |f|
            f.attr << :Subscribed if is_inbox?(f.name) || folders_contain?(subscribed_list, f.name)
          end
          
          if include_attr.is_a?(Array)
            include_attr.each do |attr|
              folder_list.delete_if { |f| !f.attr.include?(attr) }
            end
          end
          
          if exclude_attr.is_a?(Array)
            exclude_attr.each do |attr|
              folder_list.delete_if { |f| f.attr.include?(attr) }
            end
          end
          
          folder_list
        end
        
        # Create a new folder.
        
        def folder_create(path, subscription, recurse = true)
          
          do_subscription = (!subscription.nil?)
          
          @rwlock.write {
            all_folders = list("", "*")
            validate_allowed_to_create(path, all_folders)
            
            create_parents(path, all_folders) if recurse || recurse_folder_creation?
            create(path)
            
            subscribe(path, subscription) if do_subscription
          }
          
        end
        
        # Update a folder (folder path).
        
        def folder_update(path, new_path, subscription, recurse = true)
          
          do_subscription = (!subscription.nil?)
          do_rename = (!new_path.nil? && !new_path.empty? && path != new_path && !is_inbox?(new_path))
          
          return if !do_subscription && !do_rename
          
          @rwlock.write {
            all_folders = list("", "*")
            
            if do_rename
              validate_allowed_to_rename(path, new_path, all_folders)
              validate_allowed_to_subscribe(new_path, all_folders) if do_subscription
            else
              validate_allowed_to_subscribe(path, all_folders) if do_subscription
            end
            
            # carry over subscription value unless explicitly set
            subscription = folder_is_subscribed?(path) unless do_subscription
            
            if do_rename
              
              # unsubscribe old folder unless it's the INBOX (will be duplicated on RENAME)
              subscribe(path, false) unless is_inbox?(path)
              
              create_parents(new_path, all_folders) if recurse || recurse_folder_creation?
              rename(path, new_path)
              
              path = new_path
              noop # wait for server
              
            end
            
            # update subscription
            subscribe(path, subscription)
          }
          
        end
        
        # Remove a folder permamently.
                
        def folder_delete(path, recurse = true)
          
          @rwlock.write {
            all_folders = list("", "*")
            
            validate_allowed_to_delete(path, recurse, all_folders)
            
            if recurse
              # unsubscribe and delete folder and its subfolders
              all_folders.sort { |f1, f2| f2.name.count(@delimiter) <=> f1.name.count(@delimiter) }.each do |f|
                if f.name.upcase.include?(path.upcase) && !f.attr.include?(:Noselect)
                  subscribe(f.name, false)
                  delete(f.name)
                end
              end
              
            else
              # only unsubscribe and delete this folder
              subscribe(path, false)
              delete(path)
            end
          }
          
        end
        
        # Expunge messages from a folder.
        
        def folder_expunge(path)
          @rwlock.write {
            select(path)
            expunge!
          }
        end
        
        # Retrieve folder status.
        
        def folder_status(path)
          unselect
          status(path)
        end
        
        private
        
        # apply filter rules to a Net::IMAP::MailboxList
        
        def filter_folders_by_attr(folder_list, include_attr, exclude_attr)
          
          folder_list.delete_if do |folder|
            delete_folder = false
            
            exclude_attr.each do |attr|
              if folder.attr.include?(attr)
                delete_folder = true
                break
              end
            end
            
            include_attr.each do |attr|
              if !folder.attr.include?(attr)
                delete_folder = true
                break
              end
            end
            
            delete_folder
          end
          
          folder_list
        end
        
        # check whether a folder can be created in a certain path, supplying a folder_list for further
        # inspection if available
        
        def allowed_to_create?(path, folder_list)
          # folder name is invalid
          return "invalid folder name" if path.nil? || is_rootdir?(path) || is_inbox?(path)
          
          folders = path.split(@delimiter)
          folder_depth = folders.length
          
          # folder too deep
          return "folder path too deep" if (@max_folder_depth && folder_depth > @max_folder_depth)
          
          # new folder in root dir
          return "root dir does not allow inferiors" if (folder_depth == 1) && !@rootdir_writeable
          
          # folder exists
          return "folder exists" if folder_exists?(path)
          
          unless folder_list.nil?
            # check each parent dir for write-protection
             (folder_depth - 1).times do
              folders.pop
              folder_path = folders.join(@delimiter)
              
              folder = folder_list.find { |f| f.name.upcase == folder_path.upcase }
              
              if folder.nil?
                # new folder in root dir
                return "root dir does not allow inferiors" if (folders.length == 1) && !@rootdir_writeable
              else
                # no subfolders in allowed in parent folder
                return "parent folder does not allow inferiors" if folder.attr.include?(:Noinferiors)
              end
              
            end
          end
          
          nil
        end
        
        # raise exception if folder cannot be created within a certain path
        
        def validate_allowed_to_create(path, folder_list)
          message = allowed_to_create?(path, folder_list)
          raise Errors::FolderCreationNotPermitted.new(path, message) unless message.nil?
        end
        
        # check whether a folder can be renamed
        
        def allowed_to_rename?(path)
          return "invalid folder name" if path.nil? || is_rootdir?(path)
          nil
        end
        
        # raise exception if folder cannot be renamed
        
        def validate_allowed_to_rename(path, new_path, folder_list)
          message = allowed_to_rename?(path)
          raise Errors::FolderModificationNotPermitted.new(path, message) unless message.nil?
          
          message = allowed_to_create?(new_path, folder_list)
          raise Errors::FolderModificationNotPermitted.new(new_path, message) unless message.nil?
        end
        
        # check whether a folder can subscribed or unsubscribed
        
        def allowed_to_subscribe?(path, folder_list)
          return "invalid folder name" if path.nil? || is_rootdir?(path) || is_inbox?(path)
          
          unless folder_list.nil?
            exists = false
            
            folder_list.each do |f|
              if (f.name.upcase == path.upcase)
                return "folder is not selectable" if f.attr.include?(:Noselect)
                exists = true
              end
            end
            
            return "folder does not exist" if !exists
          end
          
          nil
        end
        
        # raise exception if folder cannot be subscribed or unsubscribed
        
        def validate_allowed_to_subscribe(path, folder_list)
          message = allowed_to_subscribe?(path, folder_list)
          raise Errors::FolderModificationNotPermitted.new(path, message) unless message.nil?
        end
        
        # check whether a folder can be deleted, supplying a folder_list for further
        # inspection if available
        
        def allowed_to_delete?(path, recurse, folder_list)
          return "invalid folder name" if path.nil? || is_rootdir?(path) || is_inbox?(path)
          
          unless folder_list.nil?
            exists = false
            
            folder_list.each do |f|
              if (f.name.upcase == path.upcase)
                return "folder is not selectable" if f.attr.include?(:Noselect)
                exists = true
                break if recurse # don't care about possible subfolders
              elsif !recurse
                return "folder contains subfolders" if f.name.upcase.include?(path.upcase)
              end
            end
            
            return "folder does not exist" if !exists
          end
          
          nil
        end
        
        # raise exception if folder cannot be deleted
        
        def validate_allowed_to_delete(path, recurse, folder_list)
          message = allowed_to_delete?(path, recurse, folder_list)
          raise Errors::FolderRemovalNotPermitted.new(path, message) unless message.nil?
        end
        
        # check whether the given folder is the Inbox
        
        def is_inbox?(path)
          path.upcase == standard_folder(:Inbox).upcase
        end
        
        # check whether the given folder is the root directory
        
        def is_rootdir?(path)
          path.empty? || path.chomp(@delimiter).empty?
        end
        
        # check whether a Net::IMAP::MailboxList contains a folder with a certain path
        
        def folders_contain?(folder_list, path)
          !folder_list.nil? && !folder_list.empty? && !!folder_list.find { |f| f.name.upcase == path.upcase }
        end
        
        # create missing parent folders for a folder in a given path
        
        def create_parents(path, folder_list)
          unless folder_list.nil?
            folders = path.split(@delimiter)
            folders.pop
            
            folder_depth = folders.length
            path = folders.shift
            
            folders_created = []
            
            folder_depth.times do
              exists = folder_exists?(path)
              create(path) unless exists
              
              folder = list("", path).first
              
              unless exists
                folder.attr << :Subscribed if folder_is_subscribed?(path)
                folders_created << folder
              end
              
              # no more subfolders allowed
              if folder.attr.include?(:Noinferiors)
                # rollback
                folders_created.reverse_each do |f|
                  subscribe(f.name, false) if f.attr.include?(:Subscribed)
                  delete(f.name)
                end
                raise Errors::FolderCreationNotPermitted.new(path, "folder path too deep")
              end
              
              path += "#{@delimiter}#{folders.shift}"
            end
          end
        end
        
      end
      
      # Implement commands to interact with server capabilities.
      
      module Capabilities
        
        include Generic
        
        # List of server capabilities that can be queried directly using the <tt>supports_*?</tt> methods.
        # Also see <tt>method_missing</tt>.
        
        SUPPORTED_CAPABILITY_QUERIES = [ "SORT", "UNSELECT" ]
        
        # Retrieve authentication mechanisms supported by the server.
        
        def auth_types
          @capabilities.synchronize { @capabilities.collect { |c| c.auth? }.compact }
        end
        
        # Check whether LOGINDISABLED is set.
        
        def login_disabled?
          @capabilities.synchronize { @capabilities.include?("LOGINDISABLED") }
        end
        
        # Check whether IMAP4rev1 is supported.
        
        def imap4rev1?
          @capabilities.synchronize { @capabilities.include?("IMAP4REV1") }
        end
        
        def respond_to?(method_id)  #:nodoc:
          return true if queryable_capabilities(method_id)
          super
        end
        
        # Forward method calls like
        #
        #   supports_{capability}?
        #
        # for all server capabilities contained in SUPPORTED_CAPABILITY_QUERIES to the
        # internal @capabilities list.
        
        def method_missing(method_id, *args)
          if cap = queryable_capabilities(method_id)
            @capabilities.synchronize { @capabilities.include?(cap) }
          else
            super
          end
        end
        
        private
        
        def queryable_capabilities(method_id)
          if match = /^supports_([\w]+[_\w]+)\?$/.match(method_id.to_s)
            method = match.captures.first.upcase
            return method if SUPPORTED_CAPABILITY_QUERIES.include?(method)
          end
          return nil
        end
        
      end
      
    end
    
  end
  
end
