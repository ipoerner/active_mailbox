module ActiveMailbox
  
  # Active Mailbox is my attempt to bring object-relational mapping à la Active Record
  # (http://ar.rubyonrails.org) to IMAP mailboxes.
  #
  # The library provides a straight-forward interface to acces messages and mailboxes stored
  # on a number of IMAP servers, just like Active Record does to access relational databases.
  # There are some noteable differences to Active Record, however.
  #
  # == Domain Classes
  #
  # First of all, Active Mailbox provides exactly two different domain classes to work with: one
  # class to access your messages, and one class to access mailboxes (IMAP folders). Both are created
  # more or less automatically once a class derives from ActiveMailbox::Base, like this:
  #
  #   require 'active_mailbox'
  #   
  #   class MyClass < ActiveMailbox::Base
  #     folder_class :default
  #     message_class "MyPersonalMessageClass"
  #   end
  #
  # This will create two classes: <tt>MyClass::ImapFolder</tt> to access folders and
  # <tt>MyClass::MyPersonalMessageClass</tt> to access messages. There are only a few reasons why a
  # user would want to further modify either of these classes, but of course you're free to do so.
  # Just make sure that you don't break functionality by overwriting some crucial methods. For further
  # information, refer to the ActiveMailbox::Base::ImapFolder and ActiveMailbox::Base::ImapMessage
  # modules.
  #
  # As the upper example already implies, you can specify your own names for the domain classes by
  # passing a String to the macros <tt>folder_class</tt> and <tt>message_class</tt>, or alternatively
  # pass <tt>:default</tt> if you wish to stick with the standard names.
  #
  # == Data Sources
  #
  # Contrary to the Active Record library, Active Mailbox provides data sources (connections) on a
  # per-user base. This means that each potential user gets it's very own connection and that connections
  # don't have to be shared among users. In fact, a user can specify his or her very own IMAP server to
  # work with. This is especially useful if you want to write a distributed application where users are
  # supposed to create and manage their own accounts. And yes, you may allow one user to work with
  # multiple connections at once.
  #
  # However, this kind of flexibilty has its price. First of all, it requires you to establish
  # connections manually. To do so, you have to call the <tt>establish_connection</tt> method along with
  # the ID of the connection you want to use, like this:
  #
  #   MyClass.establish_connection(connection_id)
  #
  # Further, each call to one of the domain classes' class methods requires the ID of the connection you
  # want to use as the first parameter. For instance:
  #
  #   MyClass::MyFolder.find(connection_id, :all)
  #
  # And last but not least, you should close the connection once it's not needed anymore, using
  # <tt>disconnect!</tt>:
  #
  #   MyClass.disconnect!(connection_id)
  #
  # Active Mailbox also supports mechanisms to observe and terminate inactive connections after a certain
  # amount of time (connection timeout) has passed. You should really take care about this by yourself,
  # though. The main purpose of this feature is to get rid of connections that have previously been
  # established through user-interaction and have - for whatever reason - been abandoned (system crash,
  # browser or application closed without logging out, etc.)
  #
  # The good news is: once you have aquired an object from one of the domain classes, the connection ID
  # is stored in that object and must not be supplied anymore:
  #
  #   folder = MyClass::MyFolder.find(connection_id, :Trash)
  #   messages = folder.messages
  #
  # You may be wondering where to specify your actual connections. The answer is that it's up to you
  # where to specify them. I would suggest that they come from a relational database or a similar place,
  # maybe they are also coupled with your applications user accounts. Wherever they come from, you must
  # provide an interface to your account management to Active Mailbox. Have a look at the
  # ActiveMailbox::ImapAuthenticator module.
  #
  # == Connection Adapters
  #
  # Active Mailbox uses a collection of connection adapters to deal with different types of IMAP servers.
  # You are free to specify an adapter by yourself or alternatively let Active Mailbox chose one for you.
  # If the server doesn't provide any valuable information on its type, the ImapClassifier class will
  # apply various classification methods to it. There's a chance of failure to these methods however, so
  # you should probably encourage the user to play around with various drivers incase he encounters any
  # problems.
  #
  # You are also encouraged to provide your own adapter classes if a certain server type is not supported
  # natively. Generally speaking, any adapter must be derived from the
  # ConnectionAdapters::AbstractImapAdapter class. You may want to build your adapter on top of the
  # ConnectionAdapters::GenericAdapter though, which already implements a ton of functionality.
  # 
  # In order to use an adapter class, the class must register itself at the ConnectionAdapters::AdapterPool
  # class.
  
  class Base
    
    # Default name of the folder class.
    
    DEFAULT_FOLDER_CLASS = "ImapFolder"
    
    # Default name of the message class.
    
    DEFAULT_MESSAGE_CLASS = "ImapMessage"
    
    DEFAULT_RESOLVE_CLASS = "OptionsResolve" #:nodoc:
    
    GENERIC_CHANGED_METHOD = /^([_a-zA-Z]\w*)_changed\?$/ #:nodoc:
    
    # Connection ID
    
    attr_reader :conn_id
    
    # Common constructor for both the folder class and the message class.
    
    def initialize(conn_id)
      if conn_id.nil?
        raise(ArgumentError, "conn_id can't be NIL")
      end
      @conn_id = conn_id
      @new_record = true
    end
    
    # Whether this object has changed.
    
    def changed?
      @changed && !@changed.empty?
    end
    
    # Whether this object is a new record (not persistent to the IMAP server yet).
    
    def new_record?
      @new_record || false
    end
    
    # Retrieve folder class.
    
    def folder_class
      @@folder_class
    end
    
    # Retrieve message class.
    
    def message_class
      @@message_class
    end
    
    def resolve_class #:nodoc:
      @@resolve_class
    end
    
    def respond_to?(method_id) #:nodoc:
      case method_id.to_s
        when GENERIC_CHANGED_METHOD
          true
      end
      
      super
    end
    
    # Allows calls in the form of
    #
    #   {attribute}_changed?
    #
    # in order to check whether specific attributes have changed.
    
    def method_missing(method_id, *args)
      case method_id.to_s
        when GENERIC_CHANGED_METHOD
          return (changed? && @changed.include?($1.to_sym))
      end
      
      super
    end
    
    class << self
      
      VALID_RESOLVE_CALLS = [ :timeout, :path, :folderpath, :subscription, :attributes, :messagepath, :search, :fetch, :sort, :generic_find, :command, :format, :paginate ] #:nodoc:

      VALID_LOCATION_OPTIONS = [ :delim, :default ] #:nodoc:

      VALID_CAPABILITY_OPTIONS = [ :timeout ] #:nodoc:
      
      GENERIC_RESOLVE_OPTION = /^resolve_([_a-zA-Z]\w*)_option$/ #:nodoc:
      
      @@authenticator = nil
      @@folder_class  = nil
      @@message_class = nil
      @@resolve_class = nil
      
      # Use this method to register an authenticator class (a class that acts as an interface to
      # your applications account management). Also see ActiveMailbox::ImapAuthenticator.
      
      def authenticate_through(proxy)
        if proxy.class == Class && proxy.respond_to?(:connection_specification)
          @@authenticator ||= proxy
#          proxy.instance_eval do
#            include ActiveMailbox::ImapAuthenticator
#          end
        end
      end
      
      # Set the name of the folder class.
      
      def folder_class(name = nil)
        unless name.nil?
          name = DEFAULT_FOLDER_CLASS if (name == :default)
          create_folder_class!(name)
        end
        @@folder_class
      end
      
      # Set the name of message class.
      
      def message_class(name = nil)
        unless name.nil?
          name = DEFAULT_MESSAGE_CLASS if (name == :default)
          create_message_class!(name)
        end
        @@message_class
      end
      
      def resolve_class #:nodoc:
        @@resolve_class
      end
      
      # Retrieve a ImapConnectionSpecification object from the authenticator class.
      
      def connection_specification(id)
        if @@authenticator
          @@authenticator.connection_specification(id)
        else
          raise(Errors::AbstractMethodCall, "No authenticator")
        end
      end
      
      # Get the server's list of supported capabilities. Valid options include:
      #
      # * <tt>:timeout</tt> - Maximum amount of time allowed for this call. Default value is 5 seconds.
      
      def capabilities(conn_id, *args)
        options = args.extract_options!
        options.assert_valid_keys(VALID_CAPABILITY_OPTIONS)
        
        timeout = resolve_timeout_option(options[:timeout], 5.seconds)
        
        with_connection(conn_id, timeout) { |conn|
          conn.capabilities
        }
      end
      
      # Get the folder delimiter for a specific connection. Folder delimiters are used to separate
      # folder names in a folder tree.
      
      def delimiter(conn_id)
        with_connection(conn_id) { |conn|
          conn.delimiter
        }
      end
      
      # Generate a new ImapPath object. Optional arguments include:
      #
      # * <tt>:delim</tt> - The delimiter to use for the ImapPath object.
      # * <tt>:default</tt> - The default path to apply incase the +path+ parameter is not valid.
      
      def new_location(conn_id, path, *args)
        options = args.extract_options!
        options.assert_valid_keys(VALID_LOCATION_OPTIONS)
        
        path = resolve_path_option(conn_id, path, options[:default])
        
        ImapPath.new(path, options[:delim] || delimiter(conn_id))
      end
      
      # Get the full path for one of the standard folders of a specific connection. Standard folders
      # include the 'Inbox', 'Trash', 'Drafts', 'Sent' and the 'Root' directories. They are addressed via one of
      # the following symbols:
      #
      # * <tt>:Inbox</tt> - The INBOX directory where all incoming mails are stored.
      # * <tt>:Drafts</tt> - The default directory where your drafts are stored.
      # * <tt>:Root</tt> - The root directory (that cannot be removed or unsubscribed and cannot hold any messages by itself)
      # * <tt>:Sent</tt> - The directory that contains copies of your sent messages.
      # * <tt>:Trash</tt> - The default trashcan, where deleted messages go.
      #
      # For example, :Trash may point to "Inbox.Trash" or just "Trash", depending on the connection
      # specified.
      
      def standard_folder(conn_id, symbol)
        with_connection(conn_id) { |conn|
          # does not require timeout
          conn.standard_folder(symbol)
        }
      end
      
      def inherited(subclass) #:nodoc:
        unless @@resolve_class
          name = DEFAULT_RESOLVE_CLASS
          create_resolve_class!(name, subclass)
        end
      end
      
      def respond_to?(method_id) #:nodoc:
        case method_id.to_s
          when GENERIC_RESOLVE_OPTION
            return VALID_RESOLVE_CALLS.include?($1.to_sym)
        end
        
        super
      end
      
      def method_missing(method_id, *args) #:nodoc:
        case method_id.to_s
          when GENERIC_RESOLVE_OPTION
            if VALID_RESOLVE_CALLS.include?($1.to_sym)
              return @@resolve_class.send(method_id, *args)
            end
        end
        
        super
      end
      
      private
      
      def create_folder_class!(name)
        @@folder_class ||= create_class(name.to_s, self) do
          include ImapFolder
        end
      end
      
      def create_message_class!(name)
        @@message_class ||= create_class(name.to_s, self) do
          include ImapMessage
        end
      end
      
      def create_resolve_class!(name, superclass)
        @@resolve_class = create_class(name, Object) do
          @@base_class = superclass
          
          private
          
          def self.base_class
            @@base_class
          end
        end
        
        Object.const_get(superclass.name).const_set(name, @@resolve_class)
        @@resolve_class.extend(BaseOptionsResolve)
        @@resolve_class.extend(FolderOptionsResolve)
        @@resolve_class.extend(MessageOptionsResolve)
      end
      
      def create_class(name, superclass, &block)
        klass = Class.new(superclass, &block)
        Object.const_get(superclass.name).const_set(name, klass)
        klass
      end
      
    end
    
  end
  
end