class TestConnectionAdapter < Test::Unit::TestCase
  
  def test_001_respond_to
    TestHelper::Output.puts_test_log("ConnectionAdapter respond_to")
    
    config = ActiveMailbox::Base::ImapConfig.new("test", "", "", {})
    conn = ActiveMailbox::ConnectionAdapters::GenericAdapter.new(config)
    
    native_methods     = [ :adapter_name ]
    custom_methods     = [ :auth_type, :connected?, :authenticated? ]
    supports_methods   = ActiveMailbox::ConnectionAdapters::GenericAdapter::SUPPORTED_CAPABILITY_QUERIES
    unsupported_method = :supports_blah?
    
    native_methods.each do |method_id|
      assert(conn.class.respond_to?(method_id))
    end
    
    custom_methods.each do |method_id|
      assert(conn.respond_to?(method_id))
    end
    
    supports_methods.each do |method_id|
      method_id = "supports_#{method_id.downcase}?".to_sym
      assert(conn.respond_to?(method_id))
    end
    
    # this method is not supported
    assert(!conn.respond_to?(unsupported_method))
    assert_raises(NoMethodError) { conn.send(unsupported_method) }
    
  end
  
end
