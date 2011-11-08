$:.unshift(File.dirname(File.expand_path(__FILE__)))
Dir.glob(File.join(File.dirname(__FILE__), 'struct/*.rb')).each {|f| require f }
$:.shift
