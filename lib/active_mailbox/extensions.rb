Dir.glob(File.join(File.dirname(__FILE__), 'extensions/*.rb')).each {|f| require f }

#
# Core extensions
#

class Array #:nodoc:
  include ActiveMailbox::Extensions::Core::Array
end

class Hash #:nodoc:
  include ActiveMailbox::Extensions::Core::Hash
end

class Numeric #:nodoc:
  include ActiveMailbox::Extensions::Core::Numeric
end

class String #:nodoc:
  include ActiveMailbox::Extensions::Core::String
end

#
# Net::IMAP extensions
#

module Net #:nodoc:
  class IMAP #:nodoc:
    include ActiveMailbox::Extensions::NetImap::RaceConditionFix
    include ActiveMailbox::Extensions::NetImap::Messages
    include ActiveMailbox::Extensions::NetImap::FetchMacros
    include ActiveMailbox::Extensions::NetImap::SearchInternalFix
    include ActiveMailbox::Extensions::NetImap::Unselect
    class ResponseParser #:nodoc:
      include ActiveMailbox::Extensions::NetImap::NoByeResponseFix
    end
  end
end
