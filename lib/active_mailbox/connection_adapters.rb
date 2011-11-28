$:.unshift(File.dirname(File.expand_path(__FILE__)))
require 'connection_adapters/adapter_pool'
require 'connection_adapters/connection_handler'
require 'connection_adapters/connection_observer'
require 'connection_adapters/abstract'
require 'connection_adapters/connection_pool'
require 'connection_adapters/generic_adapter'
require 'connection_adapters/concrete'
$:.shift