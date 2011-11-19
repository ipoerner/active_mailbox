module ActiveMailbox
  
  module Extensions #:nodoc:
    
    # This module contains all the extensions the the core Ruby classes. These extensions are
    # not documented in detail (yet).
    
    module Core
    
      module String #:nodoc:
        
        def strip_char(separator)
          str = self
          if RUBY_VERSION >= "1.9"
            str[0]            = "" while str.starts_with?(separator)
            str[str.length-1] = "" while str.ends_with?(separator)
          else
            str[0]            = "" while (str.index(separator) == 0)
            str[str.length-1] = "" while (str.index(separator,-1) == str.length-1)
          end
          str
        end
        
      end
      
      module Numeric #:nodoc:
        
        MAGNITUDES_LONG  = [ "Byte(s)", "Kilobyte(s)", "Megabyte(s)", "Gigabyte(s)", "Terabyte(s)", "Petabyte(s)", "Exabyte(s)"]
        MAGNITUDES_SHORT = [ "Byte", "Kb", "Mb", "Gb", "Tb", "Pb", "Eb"]
        
        def bytes_to_str(short = true)
          size  = self
          order = 0
          while (size >= 1024)
            size = (size.to_f/1024).round
            order = order.next
          end
          magnitude = (short) ? MAGNITUDES_SHORT[order] : MAGNITUDES_LONG[order]
          size = "#{size} #{magnitude}"
        end
        
      end
      
      module Array #:nodoc:
        
        if RUBY_VERSION < "1.8.7"
          
          def shuffle!
            size.downto(1) { |n| push(delete_at(rand(n))) }
            self
          end
          
          def shuffle
            s = self
            s.shuffle!
          end
          
        end
        
      end
      
      module Hash #:nodoc:
        
        def assert_valid_keys(*valid_keys)
          unknown_keys = keys - [valid_keys].flatten
          raise(ArgumentError, "Invalid key(s): #{unknown_keys.join(", ")}") unless unknown_keys.empty?
        end
        
        def reverse_merge(other_hash)
          other_hash.merge(self)
        end
  
        def reverse_merge!(other_hash)
          replace(reverse_merge(other_hash))
        end
        
      end
    
    end
    
  end
  
end
