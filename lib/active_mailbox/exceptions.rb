module ActiveMailbox
  
  module Errors
    
    # Superclass for all Active Mailbox errors.
    
    class ActiveMailboxError < StandardError
    end
    
    
    
    # Generic Configuration error.
    
    class ConfigurationError < ActiveMailboxError
    end
    
    
    
    # Indicates that an abstract method has been called. Since there's no such thing as an
    # abstract method in Ruby, this exception is used to emulate the behaviour. Usually appears
    # if some classes have not been specialized correctly by the application using Active Mailbox.
    
    class AbstractMethodCall < ActiveMailboxError
    end
    
    # Occurs when an attempt is made to create a new connection without having properly specified a
    # adapter class.
    
    class AdapterNotSpecified < ActiveMailboxError
    end
    
    # An adapter has been specified but the corresponding class cannot be found.
    
    class AdapterNotFound < ActiveMailboxError
    end
    
    # Raised when an attempt to classify an IMAP server using a certain mathod has failed.
    
    class ClassificationFailed < ActiveMailboxError
    end
    
    
    
    # Generic error that occurs when something went wrong during the communication with the IMAP
    # server. This acts as a wrapper for the actual exception that has caused the error.
    
    class ConnectionError < ActiveMailboxError
      
      # The original exception that caused the error.
      
      attr_reader :exception
      
      def initialize(exception = nil)
        super
        @exception = exception
      end
      
      def message
        (@exception) ? @exception.message : super
      end
      
      def backtrace
        (@error) ? @error.backtrace : super
      end
    end
    
    # An attempt to authenticate at the IMAP server has failed.
    
    class AuthenticationFailed < ConnectionError
    end
    
    # An attempt to connect with the IMAP server has failed.
    
    class ConnectionFailed < ConnectionError
    end
    
    # An attempt to execute a command on the IMAP Server has been made while the connection was
    # not established.
    
    class ConnectionNotEstablished < ConnectionError
    end
    
    # The connection has unexpectedly been closed.
    
    class ConnectionTerminated < ConnectionError
    end
    
    # The connection has timed out.
    
    class ConnectionTimeout < ConnectionError
    end
    
    
    
    # Occurs when a specific IMAP command is not supported by the server.
  
    class ImapCommandNotSupported
      
      # The name of the command that failed.
      
      attr_reader :command
      
      def initialize(command)
        @command = command
        super
      end
      
      def message
        "IMAP command not supported: #{@command}"
      end
      
    end
    
    
    
    # Generic error that occurs when something went wrong in the folder class. Contains the folder path.
    
    class FolderError < ActiveMailboxError
      
      # The folder path.
      
      attr_reader :path
      
      def initialize(path, details = nil)
        super()
        @path = path
        @details = details
      end
      
      def details
        (@details) ? " (#{@details})" : ""
      end
    end
    
    # The folder cannot be modified.
    
    class FolderModificationNotPermitted < FolderError
      def message
        "Modification of folder '#{@path}' not permitted#{details}."
      end
    end
    
    # The folder cannot be created.
    
    class FolderCreationNotPermitted < FolderError
      def message
        "Creation of folder '#{@path}' not permitted#{details}."
      end
    end
    
    # The folder cannot be removed.
    
    class FolderRemovalNotPermitted < FolderError
      def message
        "Removal of folder '#{@path}' not permitted#{details}."
      end
    end
    
    
    
    # If a specific record could not be found.
    
    class RecordNotFound < ActiveMailboxError
      
      # Record ID (folder name or message ID).
      
      attr_reader :id
      
      def initialize(id = nil, msg = nil)
        super(msg)
        @id = id
      end
    end
    
    # If a specific folder could not be found.
    
    class FolderNotFound < RecordNotFound
    end
    
    # If a specific message could not be found.
    
    class MessageNotFound < RecordNotFound
      
      # Name of the folder that's supposed to contain the message.
      
      attr_reader :folder
      
      def initialize(id = nil, folder = nil, msg = nil)
        super(msg, id)
        @folder = folder
      end
    end
    
  end
  
end
