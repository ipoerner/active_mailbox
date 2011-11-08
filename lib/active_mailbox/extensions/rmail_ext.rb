#
# ActiveMailbox is making heavy use of the RMail library to parse and create RFC822 messages. A lot of
# things are missing in comparison to the more popular TMail library, but I found the parser to be much
# more stable.
#
# Consequently, a lot of additions and modifications have been made. Atm, the TMail::Unquoter class is
# also used to handle strings in quoted-printable format, which should hopefully be replaced soon(ish).
#

module RMail
  
  Attachment = Struct.new(:filename, :type, :content, :size, :disposition)
  
  # This class is using the TMail::Unquoter class methods.
  
  module Utils
    
    class << self
      
      # Convert a string between two charsets. If the string is in 'quoted-printable' format,
      # it will be unquoted.
      
      def unquote_and_convert_to(s, from_charset = 'iso-8859-1', to_charset = 'utf-8')
        return s if s.nil? || s.empty?
        # some header fields contain special information on quoting and charset
        if s.match( /(.*?)(?:(?:=\?(.*?)\?(.)\?(.*?)\?=))/ )
          TMail::Unquoter.unquote_and_convert_to(s,to_charset,from_charset)
        else
          TMail::Unquoter.convert_to(s,to_charset,from_charset)
        end
      end
      
    end
    
  end
  
  class Header
    
    class Field
      
      FOLDED_HEADER_FIELD_PATTERN_RE = %r{
            \n[\s^\n] | \r\n[\s^(\r\n)]
        }x  #:nodoc
      
      # Modified this method to support multiline ('folded') fields. Folding happens
      # by replacing linear-white-space with CRLF immediately followed by one or more
      # LWSP-chars, however a lot of programs seem to violate the linear-white-space
      # rule and use folding anywhere they want.
      # 
      # Consequently, the "folded field" pattern is not replaced by a LWSP but removed
      # instead, even though this does not correspond with the RFC822 standard.
      
      def Field.parse(field)
        field = field.to_str
        if field =~ EXTRACT_FIELD_NAME_RE
          [ $1, $'.chomp.gsub(FOLDED_HEADER_FIELD_PATTERN_RE, ' ') ]
        else
          [ "", Field.value_strip(field).gsub(FOLDED_HEADER_FIELD_PATTERN_RE, '') ]
        end
      end
      
    end
    
  end
  
  # Extensions to the RMail::Header class
  
  class Header
    
    # A list of header fields that can be retrieved unquoted using the <tt>unquoted_*</tt> methods.
    # Also see <tt>method_missing</tt>.
    
    UNQUOTED_METHODS = [ :subject, :address, :field, :filename ]
    
    # Set the sender of the message.
    
    def sender=(addresses)
      address_list_assign('Sender', addresses)
    end
    
    def charset(default = 'us-ascii')  #:nodoc:
      param('content-type', 'charset', default).downcase
    end
    
    alias_method :content_type_original, :content_type  #:nodoc:
    
    def content_type(default = 'text/plain')  #:nodoc:
      # using new default value
      content_type_original(default)
    end
    
    def content_disposition(default = nil) #:nodoc:
      # inspired by original content_type method
      if value = self['content-disposition']
        value.strip.split(/\s*;\s*/)[0].downcase
      else
        if block_given?
          yield
        else
          default
        end
      end
    end
    
    alias_method :content_type_naive, :content_type  #:nodoc:
    alias_method :content_disposition_naive, :content_disposition  #:nodoc:
    alias_method :charset_naive, :charset  #:nodoc:
    
    # Get charset parameter from the endmost content-type field specified. If there is no
    # such field or parameter, defaults to 'us-ascii' according to RFC822.
    
    def charset(default = 'us-ascii')
      unless (f = all_fields_with_params('content-type')).empty?
        c = f.last[:params]['charset'] || default
        c.downcase
      else
        default
      end
    end
    
    # Get value from the endmost content-type field specified. If there is no such field,
    # defaults to 'text/plain' according to RFC822.
    
    def content_type(default = 'text/plain')
      unless (f = all_fields_with_params('content-type')).empty?
        f.last[:value].downcase
      else
        default
      end
    end
    
    # Get value from the endmost content-disposition field specified. If there is no such
    # field, defaults to nil.
    
    def content_disposition(default = nil)
      unless (f = all_fields_with_params('content-disposition')).empty?
        f.last[:value].downcase
      else
        default
      end
    end
    
    # Retrieve filename of message. There are different possibilities for the location
    # of that information, if none of them matches but the message is marked as an
    # attachment, return the default value.
    
    def filename(default = 'attachment')
      name = (
           self['content-location'] ||
           param('content-type','name') ||
           param('content-disposition','filename') ||
           nil
      )
      name = default if (name.nil? && content_disposition == 'attachment')
      name
    end
    
    # Get an array of multiline fields. For example, both 'content-type'
    # and 'content-disposition' may be followed by alternative values without
    # repeating the field's name at the beginning of the line.
    #
    # This method iterates over all header fields and searches for occurences
    # of field_name plus all untagged fields following.
    
    def all_fields(field_name)
      old_field_name = ""
      @fields.collect { |f|
        old_field_name = name = (f.name.empty?) ? old_field_name : f.name
         (name.downcase == field_name) ? f.value : nil
      }.compact
    end
    
    # Get an array of multiline fields including value and params.
    #
    # For instance, if multiple 'content-type' header fields have been specified,
    # you may receive something like this:
    #
    #   message.header.all_fields_with_params("content-type")
    #   => [{:value=>"text/plain", :params=>{"charset"=>"us-ascii"}}, {:value=>"html", :params=>{"charset"=>"windows-1252"}}]
    
    def all_fields_with_params(field_name)
      all_fields(field_name).collect { |f|
        f = Utils.unquote_and_convert_to(f)
        f_value  = f.strip.split(/\s*;\s*/)[0].downcase
        f_params = params_from_value(f)
        { :value => f_value, :params => f_params }
      }.compact
    end
    
    def respond_to?(method_id)  # :nodoc:
      return true if allowed_unquote_methods(method_id)
      super
    end
    
    # Allow calls in the form of
    #
    #   unquoted_{field}
    #
    # in order to retrieve the unquoted content of header fields contained in UNQUOTED_METHODS.
    
    def method_missing(method_id, *args)
      case allowed_unquote_methods(method_id)
        when :subject
          stripped_subj = if (subj = subject)
            # subject may span over multiple lines
            subj.collect { |s| s.strip }.join
          else
            nil
          end
          Utils.unquote_and_convert_to(stripped_subj, charset)
        when :address
          type = args.first
          address(type).collect { |addr|
            Utils.unquote_and_convert_to(addr.format, charset)
          }
        when :field
          name = args.first
          name.downcase! unless name.nil?
          Utils.unquote_and_convert_to(self[name], charset)
        when :filename
          Utils.unquote_and_convert_to(filename, charset)
      else
        super
      end
    end
    
    private
    
    def allowed_unquote_methods(method_id)
      if match = /^unquoted_([_a-zA-Z]\w*)$/.match(method_id.to_s)
        method = match.captures[0].to_sym
        return method if UNQUOTED_METHODS.include?(method)
      end
      return nil
    end
    
    def address(type)
      type.downcase! unless type.nil?
      (field?(type)) ? RMail::Address.parse(self[type]) : []
    end
    
    # has been adapted to prevent code-duplication
    
#    def params_quoted(field_name, default = nil)
#      if value = self[field_name]
#        params_from_value(value)
#      else
#        if block_given? then yield field_name else default end
#      end
#    end
    
    # extracted from original params_quoted method
    # also stripping quotes from param value ("\"charset\"" => "charset")
    
    def params_from_value(value)
      params = {}
      first = true
      value.scan(PARAM_SCAN_RE) { |param|
        if param != ';'
          unless first
            name, value = param.scan(NAME_VALUE_SCAN_RE).collect { |p|
             (p == '=') ? nil : p
            }.compact
            if name && (name = name.strip.downcase) && name.length > 0
              params[name] = (value || '').strip.strip_char('"')
            end
          else
            first = false
          end
        end
      }
      params
    end
    
  end
  
  # Extensions to the RMail::Message class
  
  class Message
    
    # Default header field that stores the checksum used to identify a message.
    
    ACTIVE_MAILBOX_CHECKSUM = "X-ActiveMailbox-Checksum"
    
    # Add checksum to a messages' ACTIVE_MAILBOX_CHECKSUM header field.
    
    def prepare_for_append(checksum = nil)
      # add checksum
      unless checksum.nil?
        @header.delete(ACTIVE_MAILBOX_CHECKSUM)
        @header.add(ACTIVE_MAILBOX_CHECKSUM, checksum, 0)
      end
      
      #remove preceding "From ..." line
      @header.mbox_from = nil
      
      self
    end
    
    # Retrieve checksum from a messages' ACTIVE_MAILBOX_CHECKSUM header field.
    
    def checksum
      @header[ACTIVE_MAILBOX_CHECKSUM]
    end
    
    # Remove message checksum and From line before sending it.
    
    def prepare_for_send
      @header.delete(ACTIVE_MAILBOX_CHECKSUM)
      
      #remove preceding "From ..." line
      @header.mbox_from = nil
      
      self
    end
    
    # Convert message to string.
    
    def to_s
      require 'rmail/serialize'
      rfc822 = RMail::Serialize.new('').serialize(self)
      # FIXME: is it necessary to cope with strings that contain LF as well as CRLF ?
      #rfc822.gsub(/([^\r])(\n)/, "#{'\1'}\r\n").gsub(/([^\r])(\n)/, "#{'\1'}\r\n")
      #rfc822.gsub("\r\n", "\n").gsub("\n", "\r\n")
      rfc822.gsub("\n", "\r\n")
    end
    
    # Check whether this message is in 'text/plain' format.
    
    def plaintext?
      raise(TypeError, "Can not test multipart message for text.") if multipart?
      return (@header.content_type == 'text/plain')
    end
    
    # Check whether this message is an attachment. In case rfc822 is true, the message's
    # content_type also needs to match 'message/rfc822'.
    
    def attachment?(rfc822 = false)
      raise(TypeError, "Can not test multipart message for attachment.") if multipart?
      return (!@header.filename.nil? && (!rfc822 || @header.content_type == 'message/rfc822'))
    end
    
    # Get unquoted body of message.
    
    def unquoted_body
      raise(TypeError, "Can not unquote a multipart message.") if multipart?
      # decode body and convert charset
      Utils.unquote_and_convert_to(decode, @header.charset)
    end
    
    # Get attachment as a formatted Hash. Using the peek parameter will not include the
    # actual data but only the necessary information to describe the attachment.
    
    def attachment(peek = false)
      raise(TypeError, "Can not get attachment from multipart message.") if multipart?
      if attachment?
        # body needs to be decoded, however charset doesn't matter for binary data
        filename    = @header.filename
        type        = @header.content_type
        content     = (peek) ? "" : decode
        size        = content.length.bytes_to_str
        disposition = @header.content_disposition("attachment")
        Attachment.new(filename, type, content, size, disposition)
      else
        nil
      end
    end
    
    # Test message for attachments.
    
    def has_attachments?
      if self.multipart?
        each_part { |part|
          return true if !part.is_a?(String) && part.has_attachments?
        }
        return false
      end
      return self.attachment?
    end
    
    # Add attachment to message.
    
    def add_attachment(name, data, mime_type = 'text/plain')
      message = self.class.new
      message.header.set('content-type', mime_type, nil)
      message.header.set('content-disposition', "attachment", 'filename' => name)
      message.body = data
      add_part(message)
    end
    
    # Get attachments from message.
    
    def attachments(peek = true)
      if multipart?
        @body.collect { |part|
          if part.is_a?(String)
            # should only be entered for first element of @body
            nil
          else
            part.attachments(peek)
          end
        }.flatten.compact
      else
        # empty array for invalid attachments
        attachment(peek) || []
      end
    end
    
  end
  
end
