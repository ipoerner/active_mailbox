require 'rubygems'
require 'monitor'
require 'thread'
require 'net/imap'
require 'openssl'
require 'yaml'

require 'active_support'
require 'rmail'
require 'tmail'

$:.unshift(File.dirname(File.expand_path(__FILE__)))
require 'active_mailbox/authenticator'
require 'active_mailbox/extensions'
require 'active_mailbox/exceptions'
require 'active_mailbox/encryption'
require 'active_mailbox/options_resolve'
require 'active_mailbox/global_config'
require 'active_mailbox/classification'
require 'active_mailbox/struct'
require 'active_mailbox/base'
require 'active_mailbox/imap_folder'
require 'active_mailbox/imap_message'
require 'active_mailbox/connection_adapters'
$:.shift

# initiate and start connection observer
ActiveMailbox::ConnectionObserver.instance.start
