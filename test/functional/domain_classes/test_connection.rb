module TestConnection
  
  def test_conn001_automatic_reconnect
    TestHelper::Output.puts_test_log("automatic reconnect")
    
    sleep(2)
    ActiveMailbox::Base.cleanup!(nil, 1.seconds, nil)
    assert !ActiveImap.connected?(@record_id)
    assert_nothing_raised {
      ActiveImap::ImapFolder.find(@record_id, :Inbox)
    }
    assert ActiveImap.connected?(@record_id)
    
  end
  
  def test_conn002_terminate_session
    TestHelper::Output.puts_test_log("observer terminates session")
    
    ActiveMailbox::ConnectionObserver.instance.stop
    ActiveMailbox::GlobalConfig.connection.observer_interval = 1.seconds
    ActiveMailbox::GlobalConfig.connection.session_timeout   = 1.seconds
    ActiveMailbox::ConnectionObserver.instance.start
    
    sleep(2)
    assert_raise(ActiveMailbox::Errors::ConnectionNotEstablished) {
      ActiveImap.connected?(@record_id)
    }
    
    ActiveMailbox::ConnectionObserver.instance.stop
    ActiveMailbox::GlobalConfig.connection.observer_interval = 10.seconds
    ActiveMailbox::GlobalConfig.connection.session_timeout   = 30.minutes
    ActiveMailbox::ConnectionObserver.instance.start
    
    assert_nothing_raised {
      ActiveImap.establish_connection(@record_id)
    }
  end
  
end
