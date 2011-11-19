module ActiveMailbox
  
  class Base
    
    # Wrap a specific path of an IMAP servers' folder into a single object.
    
    class ImapPath
      
      # The folder delimiter. This is the character that separates folders in a path.
      
      attr_reader :delimiter
      
      # The folder level. Specifies how deep the folder is nested in the folder tree.
      
      attr_reader :level
      
      # The name of the folder.
      
      attr_accessor :name
      
      # Creates a new ImapPath object.
      
      def initialize(path, delim)
        @delimiter = delim
        self.path = path
      end
      
      # Compare to another ImapPath object or to a String.
      
      def ==(path)
        case path
          when ImapPath
            self.path.downcase == path.path.downcase
          when String
            self.path.downcase == path.downcase
          else
            false
        end
      end
      
      # Retrieve the full path of the folder.
      
      def path
        @path.join(@delimiter)
      end
      
      # Set the full path of the folder.
      
      def path=(p)
        @path  = p.split(@delimiter).compact
        @name  = @path.last || ""
        @level = @path.length
      end
      
      # Retrieve the full path of the parent folder.
      
      def parent_path
        return nil if path.empty?
        len = @path.length
        parent = case len
          when 1
            [""]
          when 2
            [@path.first]
          else
            @path[0..(len-2)]
        end
        parent.join(@delimiter)
      end
      
      # Retrieve the full path of a subfolder to this folder.
      
      def subfolder_path(name)
        if name.nil? || name.empty? || name.include?(@delimiter)
          return nil
        end
        return (path + @delimiter + name)
      end
      
      # Check whether the full path is superior to another path.
      
      def superior_to?(imap_path)
        case imap_path
          when self.class
            if @name.empty?
              @level < imap_path.level
            else
              imap_path.path.starts_with?(path + @delimiter)
            end
          when String
            superior_to?(self.class.new(imap_path, @delimiter))
          else
            nil
        end
      end
      
      # Check whether the full path points to the parent directory of another path.
      
      def parent_of?(imap_path)
        case imap_path
          when self.class
            superior_to?(imap_path) && (@level+1) == imap_path.level
          when String
            parent_of?(self.class.new(imap_path, @delimiter))
          else
            nil
        end
      end
      
      # Set the folder name.
      
      def name=(n)
        @name = n
        @path[-1] = @name
      end
      
      # Check whether the folder name corresponds with another folders' name.
      
      def name_is?(name)
        @name.downcase == name.chomp(@delimiter).downcase
      end
      
      # Check whether the full path corresponds with another folders' full path.
      
      def path_is?(path)
        self.path.downcase == path.chomp(@delimiter).downcase
      end
      
      # Generate the reference part of a LIST command.
      
      def list_reference(type = nil)
        ref = self.parent_path || ""
        ref = "#{ref}#{@delimiter}" unless ref.empty?
        ref
      end
      
      # Generate the wildcards part of a LIST command.
      
      def list_wildcards(type = nil)
        case type
          when :direct
            return (@name.empty?) ? "%" : "#{@name}#{@delimiter}%"
          when :all
            return (@name.empty?) ? "*" : "#{@name}#{@delimiter}*"
          else
            return (@name.empty?) ? ""  : @name
        end
      end
      
    end
    
  end

end
