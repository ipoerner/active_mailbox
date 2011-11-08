module ActiveMailbox
  
  class Base
    
    # Turn Net::IMAP::MailboxList responses into an array of ImapFolders.
    
    class MailboxListParser
      
      class << self
        
        # Parse a Net::IMAP::MailboxList array.
        
        def read(mailbox_list, conn_id, klass)
          return [] if (mailbox_list.nil? || mailbox_list.empty?)
          
          # copy into new Array
          mailbox_list.collect! { |mailbox|
            klass.instantiate(conn_id, mailbox)
          }
        end
        
      end
      
    end
    
    # This module is used to create the domain class for IMAP folders. Also see
    # ActiveMailbox::Base::ImapFolder::ClassMethods.
    
    module ImapFolder
      
      # Readable attributes:
      #
      # * <tt>id</tt> - The unique folder path.
      # * <tt>attributes</tt> - Folder attributes (:Noinferiors, :Noselect, :Marked, :Unmarked and/or :Subscribed)
      # * <tt>location</tt> - An ImapPath object that represents the folder path.
      
      ATTR_READER = %w(id attributes location)
      
      def self.included(klass)  #:nodoc:
        klass.extend(ClassMethods)
        # add attr_reader methods
        ATTR_READER.each { |attr|
          klass.module_eval %{ def #{attr}() @#{attr} end }
        }
      end
      
      # Create a new folder object.
      
      def initialize(conn_id, id, delim, attr)
        super(conn_id)
        self.class.initialize_object(self, id, delim, attr)
      end
      
      # Compare two folder objects.
      
      def ==(f)
        (@conn_id == f.conn_id && @id == f.id)
      end
      
      # Retrieve the folder path.
      
      def path
        @location.path
      end
      
      # Set the folder path.
      
      def path=(new_path)
        location = self.class.new_location(conn_id, new_path, :default => :Root)
        if !location.path.empty?
          @location = location
          location_changed!
        end
      end
      
      # Compare the folder path with another path.
      
      def path_is?(path)
        @location.path_is?(path)
      end
      
      # Retrieve the folder name.
      
      def name
        @location.name
      end
      
      # Set the folder name.
      
      def name=(new_name)
        if new_name.is_a?(String)
          unless new_name.include?(@location.delimiter)
            @location.name = new_name
            location_changed!
          end
        end
      end
      
      # Compare the folder name with another name.
      
      def name_is?(name)
        @location.name_is?(name)
      end
      
      # Retrieve the folder delimiter.
      
      def delimiter
        @location.delimiter
      end
      
      # Retrieve the folder level (how deep the folder is nested into the folder tree).
      
      def level
        @location.level
      end
      
      # Check whether the folder is subscribed.
      
      def subscribed?
        !@attributes.nil? && @attributes.include?(:Subscribed)
      end
      
      # Set the folder subscription state.
      
      def subscription=(new_subscription)
        if !new_subscription.nil?
          case new_subscription
            when true
              unless subscribed?
                @attributes << :Subscribed
                subscription_changed!
              end
            when false
              if subscribed?
                @attributes.delete(:Subscribed)
                subscription_changed!
              end
          end
        end
      end
      
      # Check whether the folder has the <tt>:Marked</tt> attribute set.
      
      def marked?
        !@attributes.nil? && @attributes.include?(:Marked)
      end
      
      #
      # Check whether the folder may contain inferiors.
      #
      
      def inferiors?
        !@attributes.nil? && !@attributes.include?(:Noinferiors)
      end
      
      # Check whether the folder can be selected.
      
      def selectable?
        !@attributes.nil? && !@attributes.include?(:Noselect)
      end
      
      # Retrieve any subfolders to this folder.
      
      def subfolders
        if new_record?
          raise Errors::FolderNotFound.new(@id, "Folder does only exist locally")
        else
          begin
            self.class.some(@conn_id, @location.path)
          rescue Errors::FolderNotFound
            []
          end
        end
      end
      
      # Check whether the folder contains any subfolders.
      
      def subfolders?
        !self.subfolders.nil?
      end
      
      # Retrieve the folders' parent folder.
      
      def parent
        parent_path = @location.parent_path
        
        if parent_path.nil?
          nil
        else
          begin
            self.class.find(@conn_id, parent_path)
          rescue Errors::FolderNotFound, parent_path
            nil
          end
        end
      end
      
      # Check whether this folder is direct parent to another folder.
      
      def parent_of?(folder)
        @location.parent_of?(folder.location)
      end
      
      # Check whether this folder is superior to another folder.
      
      def superior_to?(folder)
        @location.superior_to?(folder.location)
      end
      
      # Retrieve all messages contained in this folder.
      
      def messages(*args)
        if new_record?
          raise Errors::FolderNotFound.new(@id, "Folder does only exist locally")
        else
          if !@conn_id.nil? && !@location.nil? && selectable?
            self.class.message_class.all(@conn_id, @location.path, *args)
          else
            []
          end
        end
      end
      
      # Get folder status.
      
      def status
        self.class.status(@conn_id, @location.path)
      end
      
      # Update the name or subscription status of this folder. The +name+ may not contain the folder
      # delimiter, so that the folder is not moved to another folder.
      
      def update(new_name = nil, new_subscription = nil)
        self.name = new_name
        self.subscription = new_subscription
        save!
      end
      
      # Permamently remove all messages that have the <tt>:Deleted</tt> attribute set from this folder.
      # This action is also known as "expunge".
      
      def expunge!
        if new_record?
          raise Errors::FolderNotFound.new(@id, "Folder does only exist locally")
        else
          self.class.expunge(@conn_id, @location.path)
        end
      end
      
      # Remove this folder permamently. This is done without recursion, so that servers that don't
      # permit the removal of folders with inferiors will report an error.
      
      def delete!
        if new_record?
          raise Errors::FolderNotFound.new(@id, "Folder does only exist locally")
        else
          self.class.delete(@conn_id, @location.path)
          @id = nil
        end
      end
      
      # Create a new folder or message within this folder.
      
      def <<(folder_or_message)
        if new_record?
          raise Errors::FolderNotFound.new(@id, "Folder does only exist locally")
        else
          case folder_or_message
            when self.class.folder_class
              folder = folder_or_message
              if parent_of?(folder)
                self.class.create(@conn_id, folder.path)
              else
                raise FolderError.new(@location.path, "Folder is no parent of #{folder.path}")
              end
            when self.class.message_class
              if selectable?
                message = folder_or_message
                self.class.message_class.create(@conn_id, @location.path, message)
              else
                raise FolderError.new(@location.path, "Folder is not selectable")
              end
          end
        end
      end
      
      # Transfer any local changes to the folder to the IMAP server.
      
      def save!
        if new_record?
          self.class.create(@conn_id, @id, :subscription => subscribed?)
          @changed = []
          @new_record = false
        elsif changed?
          new_path = (location_changed?) ? @location.path : nil
          new_subscription = (subscription_changed?) ? subscribed? : nil
          
          self.class.update(@conn_id, @id, :path => new_path, :subscription => new_subscription)
          @id = @location.path
          @changed = []
          @new_record = false
        end
        
        self
      end
      
      private
      
      def location_changed!
        if new_record?
          @id = @location.path
        else
          @changed << :location
        end
      end
      
      def subscription_changed!
        unless new_record?
          @changed << :subscription
        end
      end
      
      public
      
      # ImapFolder class methods. Due to technical reasons, the connection_id must be specified each
      # time a folder is being accessed using class methods. The folder path can be a symbol describing
      # one of the standard folders. For instance:
      #
      #   ImapFolder.find(connection_id, "INBOX")
      #
      # is equal to
      #
      #   ImapFolder.find(connection_id, :Inbox)
      
      module ClassMethods
        
        VALID_FIND_OPTIONS        = [ :timeout, :attributes, :command ]  #:nodoc:
        VALID_FIND_BY_IDS_OPTIONS = [ :timeout, :attributes ]  #:nodoc:
        VALID_CREATE_OPTIONS      = [ :timeout, :recursive, :subscription ]  #:nodoc:
        VALID_UPDATE_OPTIONS      = [ :timeout, :recursive, :subscription, :path ]  #:nodoc:
        VALID_DELETE_OPTIONS      = [ :timeout, :recursive ]  #:nodoc:
        VALID_COMPRESS_OPTIONS    = [ :timeout ]  #:nodoc:
        VALID_STATUS_OPTIONS      = [ :timeout ]  #:nodoc:
        
        def instantiate(conn_id, mailbox)  #:nodoc:
          obj = allocate
          obj.instance_variable_set("@conn_id", conn_id)
          initialize_object(obj, mailbox.name, mailbox.delim, mailbox.attr)
        end
        
        def initialize_object(object, id, delim, attr)  #:nodoc:
          conn_id = object.instance_variable_get("@conn_id")
          
          if (conn_id.nil?)
            raise(ArgumentError, "conn_id can't be NIL")
          end
          
          if id.nil?
            raise(ArgumentError, "id can't be NIL")
          end
          
          if delim.nil?
            delim = delimiter(conn_id)
          end
          
          if attr.nil?
            attr = []
          end
          
          location = new_location(conn_id, id, :delim => delim)
          
          object.instance_variable_set("@id", id)
          object.instance_variable_set("@location", location)
          object.instance_variable_set("@attributes", attr)
          object.instance_variable_set("@changed", [])
          
          object
        end
        
        # Find folders matching your search criteria for a specific connection. Pass :all as first
        # option to search for any folder within the given path, or :some to only search for direct
        # subfolders.
        #
        # ==== Options
        #
        # * <tt>:timeout</tt> - Maximum amount of time allowed for this call. Default value is 30 seconds.
        # * <tt>:attributes</tt> - This can be used to filter the results by folder attributes like :Noinferiors, :Noselect, :Marked, :Unmarked or :Selected.
        # * <tt>:command</tt> - Specify a custom LIST command (only incase :all has been specified)
        
        def find(conn_id, *args)
          options = args.extract_options!
          
          folders = case args.first
            when :all
              options.assert_valid_keys(VALID_FIND_OPTIONS)
              options[:subfolders] = :all
              find_every(conn_id, options)
            when :some
              options.assert_valid_keys(VALID_FIND_OPTIONS)
              options[:subfolders] = :direct
              find_every(conn_id, options)
            else
              options.assert_valid_keys(VALID_FIND_BY_IDS_OPTIONS)
              
              ids = args.first
              ids = (ids.is_a?(Array)) ? ids.flatten.compact.uniq : [ids]
              
              raise(ArgumentError, "Couldn't find folder without an ID") if ids.empty?
              
              find_from_ids(conn_id, ids, options)
          end
          
          folders.compact!
          raise Errors::FolderNotFound if folders.empty?
          
          (folders.length > 1) ? folders : folders.first
        end
        
        # Shorthand for find(conn_id, :all, *args)
        
        def all(conn_id, *args)
          find(conn_id, :all, *args)
        end
        
        # Shorthand for find(conn_id, :some, *args)
        
        def some(conn_id, *args)
          find(conn_id, :some, *args)
        end
        
        # Check whether a specific folder exists. The same rules as for the <tt>find</tt> method apply.
        
        def exists?(conn_id, *args)
          begin
            find(conn_id, *args)
          rescue Errors::FolderNotFound
            return false
          end
          return true
        end
        
        # Create a new folder underneath a specific path.
        #
        # ==== Options
        #
        # * <tt>:timeout</tt> - Maximum amount of time allowed for this call. Default value is 10 seconds.
        # * <tt>:recursive</tt> - If non-existing parent folders should be created automatically.
        # * <tt>:subscription</tt> - Pass this option if the new folder should initially be subscribed to.
        #
        # === About the <tt>:recursive</tt> option
        # 
        # Servers behave different on this one - while some only allow to create folders underneath an already
        # existant path, others create any missing parents automatically with the <tt>:Noselect</tt>
        # attribute set. Most of the time, these are also removed automatically once a "proper" folder within
        # them deceases. Others however do not remove these special folders and there's no chance to get
        # rid of them other than on the filesystem level (i.e. by directly accessing your homedir). If you
        # don't know what kind of server you're dealing with, and you want to avoid these "dangling"
        # ghost folders, make sure that <tt>:recursive</tt> is used all the time (or alternatively,
        # by going via the <tt>create</tt>/<tt>update</tt>/<tt>delete</tt> instance methods that each
        # folder object provides).
        
        def create(conn_id, path, *args)
          options = args.extract_options!
          options.assert_valid_keys(VALID_CREATE_OPTIONS)
          
          timeout      = resolve_timeout_option(options[:timeout], 10.seconds)
          subscription = resolve_subscription_option(options[:subscription])
          path         = resolve_folderpath_option(conn_id, path)
          
          with_connection(conn_id, timeout) { |conn|
            conn.folder_create(path, subscription, options[:recursive])
          }
        end
        
        # Update the path/name or the subscription status of a folder.
        #
        # ==== Options
        #
        # * <tt>:timeout</tt> - Maximum amount of time allowed for this call. Default value is 20 seconds.
        # * <tt>:path</tt> - New path for this folder.
        # * <tt>:recursive</tt> - If non-existing parent folders should be created automatically.
        # * <tt>:subscription</tt> - Pass this option if the folder should be subscribed to.
        #
        # The <tt>:recursive</tt> option should be considered. See the <tt>create</tt> method for
        # more information.
        
        def update(conn_id, path, *args)
          options = args.extract_options!
          options.assert_valid_keys(VALID_UPDATE_OPTIONS)
          
          timeout   = resolve_timeout_option(options[:timeout], 20.seconds)
          path      = resolve_folderpath_option(conn_id, path)
          new_path  = resolve_folderpath_option(conn_id, options[:path])
          
          with_connection(conn_id, timeout) { |conn|
            conn.folder_update(path, new_path, options[:subscription], options[:recursive])
          }
        end
        
        # Remove a folder. The folder won't be moved to the trashcan or anything like that, it will
        # be REMOVED PERMAMENTLY so make sure that you're aware of what you're doing.
        #
        # ==== Options
        #
        # * <tt>:timeout</tt> - Maximum amount of time allowed for this call. Default value is 20 seconds.
        # * <tt>:recursive</tt> - Also remove any existing subfolders.
        #
        # The <tt>:recursive</tt> option works not exactly as for <tt>create</tt> or <tt>update</tt>.
        # Instead, it should be set when you want to enforce the removal of all subfolders (which is
        # not done implicitly on some servers).
        
        def delete(conn_id, path, *args)
          options = args.extract_options!
          options.assert_valid_keys(VALID_DELETE_OPTIONS)
          
          timeout = resolve_timeout_option(options[:timeout], 10.seconds)
          path    = resolve_folderpath_option(conn_id, path)
          
          with_connection(conn_id, timeout) { |conn|
            conn.folder_delete(path, options[:recursive])
          }
        end
        
        # Expunge all messages that contain the <tt>:Deleted</tt> attribute from the folder, thus
        # reducing its size.
        #
        # ==== Options
        #
        # * <tt>:timeout</tt> - Maximum amount of time allowed for this call. Default value is 20 seconds.
        
        def expunge(conn_id, path, *args)
          options = args.extract_options!
          options.assert_valid_keys(VALID_COMPRESS_OPTIONS)
          
          timeout = resolve_timeout_option(options[:timeout], 20.seconds)
          path    = resolve_folderpath_option(conn_id, path)
          
          with_connection(conn_id, timeout) { |conn|
            conn.folder_expunge(path)
          }
        end

        # Recieve the status on a certain folder.
        #
        # ==== Options
        #
        # * <tt>:timeout</tt> - Maximum amount of time allowed for this call. Default value is 20 seconds.

        def status(conn_id, path, *args)
          options = args.extract_options!
          options.assert_valid_keys(VALID_STATUS_OPTIONS)
          
          timeout = resolve_timeout_option(options[:timeout], 20.seconds)
          path    = resolve_folderpath_option(conn_id, path)
          
          with_connection(conn_id, timeout) { |conn|
            conn.folder_status(path)
          }
        end
        
        private
        
        def generate_list_command(conn_id, path, type)
          location = new_location(conn_id, path)
          with_connection(conn_id) { |conn|
            conn.list_command(location, type)
          }
        end
        
        def list_folders(conn_id, options)
          timeout = resolve_timeout_option(options[:timeout], 30.seconds)
          options = resolve_attributes_option(options)
          
          with_connection(conn_id, timeout) { |conn|
            conn.folder_retrieve(options[:command], options[:include], options[:exclude])
          }
        end
        
        #
        # Default search method.
        #
        
        def find_every(conn_id, options)
          path = resolve_folderpath_option(conn_id, options.delete(:path))
          delim = delimiter(conn_id)
          
          subfolders = options[:subfolders]
          options[:command]  ||= generate_list_command(conn_id, path, subfolders)
          
          folder_list = list_folders(conn_id, options)
          
          if (subfolders == :direct || subfolders == :all)
            folder_list.delete_if { |m| m.name.chomp(delim).upcase == path.chomp(delim).upcase }
          end
          
          folder_list = list_folders(conn_id, options)
          MailboxListParser.read(folder_list, conn_id, self)
        end
        
        #
        # Find folder from IDs
        #
        
        def find_from_ids(conn_id, ids, options)
          subfolders = nil
          
          folder_list = ids.collect { |path|
            path = resolve_folderpath_option(conn_id, path)
            options[:command] = generate_list_command(conn_id, path, subfolders)
            
            list_folders(conn_id, options)
          }.flatten.compact
          
          MailboxListParser.read(folder_list, conn_id, self)
        end
        
      end
    
    end
    
  end
  
end