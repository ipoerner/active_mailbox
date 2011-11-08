module TestMessages
  
  def test_msg001_search_with_no_results
    TestHelper::Output.puts_test_log("search with no results")
    
    assert_raise(ActiveMailbox::Errors::MessageNotFound) {
      ActiveImap::ImapMessage.all(@record_id, :Inbox, :flags => { :Seen => true, :Unseen => true })
    }
  end
  
  def test_msg002_search_with_results
    TestHelper::Output.puts_test_log("search with results")
    
    begin
      msgs = ActiveImap::ImapMessage.all(@record_id, :Inbox, :fetch => :header, :format => :rmail)
    rescue ActiveMailbox::Errors::MessageNotFound
      return
    end
    
    message = msgs.instance_of?(Array) ? msgs.first : msgs
    assert message.instance_of?(ActiveImap::ImapMessage)
    assert message.instance.is_a?(RMail::Message) && message.format == :rmail
    
    folder = message.folder
    assert folder.instance_of?(ActiveImap::ImapFolder)
    assert folder.name_is?("INBOX")
  end
  
  def test_msg003_search_with_pagination
    TestHelper::Output.puts_test_log("search with pagination")
    
    begin
      messages = ActiveImap::ImapMessage.all(@record_id, :Inbox, :fetch => :header)
    rescue ActiveMailbox::Errors::MessageNotFound
      return
    end
    
    if messages.is_a?(Array) && messages.length > 2
      ids = messages.collect { |m| m.id }
      
      messages = ActiveImap::ImapMessage.all(@record_id, :Inbox, :fetch => :header, :paginate => 0..1)
      assert messages.length == 2
      
      for i in 0...messages.length
        assert ids[i] == messages[i].id
      end
    end
  end
  
  def test_msg004_generic_find_by
    TestHelper::Output.puts_test_log("generic find_by")
    
    begin
      messages1 = ActiveImap::ImapMessage.all(@record_id, :Inbox, :date => { :Before => Time.now }, :fetch => :header)
      messages2 = ActiveImap::ImapMessage.find_by_date(@record_id, :Inbox, { :Before => Time.now }, :fetch => :header)
      messages3 = ActiveImap::ImapMessage.find_by_date_before(@record_id, :Inbox, Time.now, :fetch => :header)
      
      assert (messages1 == messages2)
      assert (messages2 == messages3)
    rescue ActiveMailbox::Errors::MessageNotFound
      # skip
    end
    
    begin
      messages1 = ActiveImap::ImapMessage.all(@record_id, :Inbox, :flags => { :Seen => true }, :fetch => :header)
      messages2 = ActiveImap::ImapMessage.find_by_flags(@record_id, :Inbox, { :Seen => true }, :fetch => :header)
      messages3 = ActiveImap::ImapMessage.find_by_flags_seen(@record_id, :Inbox, true, :fetch => :header)
      
      assert (messages1 == messages2)
      assert (messages2 == messages3)
    rescue ActiveMailbox::Errors::MessageNotFound
      # skip
    end
    
    begin
      messages1 = ActiveImap::ImapMessage.all(@record_id, :Inbox, :size => { :Smaller => 1.megabytes }, :fetch => :header)
      messages2 = ActiveImap::ImapMessage.find_by_size(@record_id, :Inbox, { :Smaller => 1.megabytes }, :fetch => :header)
      messages3 = ActiveImap::ImapMessage.find_by_size_smaller(@record_id, :Inbox, 1.megabytes, :fetch => :header)
      
      assert (messages1 == messages2)
      assert (messages2 == messages3)
    rescue ActiveMailbox::Errors::MessageNotFound
      # skip
    end
    
    begin
      messages1 = ActiveImap::ImapMessage.all(@record_id, :Inbox, :subject => "Test", :fetch => :header)
      messages2 = ActiveImap::ImapMessage.find_by_subject(@record_id, :Inbox, "Test", :fetch => :header)
      
      assert (messages1 == messages2)
    rescue ActiveMailbox::Errors::MessageNotFound
      # skip
    end
  end
  
  def test_msg005_create_destroy_messages
    TestHelper::Output.puts_test_log("create/duplicate/destroy message")
    
    message = TestHelper::Fixtures.new_message(@record_id)
    
    message.path = :Inbox
    message.save!
    original_id = message.id
    assert !original_id.nil?
    assert ActiveImap::ImapMessage.exists?(@record_id, :Inbox, original_id)
    
    message.duplicate(:Trash)
    assert !message.id.nil?
    assert ActiveImap::ImapMessage.exists?(@record_id, :Inbox, original_id)
    assert ActiveImap::ImapMessage.exists?(@record_id, :Trash, message.id)
    message.delete!
    assert !ActiveImap::ImapMessage.exists?(@record_id, :Trash, message.id)
    
    message = ActiveImap::ImapMessage.find(@record_id, :Inbox, original_id, :fetch => :header)
    message.dump!
    assert !message.id.nil?
    assert ActiveImap::ImapMessage.exists?(@record_id, :Trash, message.id, :flags => { :Deleted => true })
    assert !ActiveImap::ImapMessage.exists?(@record_id, :Inbox, original_id)
    assert message.path_is?(:Trash)
    
    message.folder.expunge!
    assert !ActiveImap::ImapMessage.exists?(@record_id, :Trash, message.id)
  end
  
  def test_msg006_update_message
    TestHelper::Output.puts_test_log("update message")
    
    message = TestHelper::Fixtures.new_message(@record_id)
    message.save!
    assert (message.id > 0)
    
    original_id = message.id
    
    message.path = :Inbox
    message.save!
    assert (message.id > 0)
    
    new_id = message.id
    
    assert !ActiveImap::ImapMessage.exists?(@record_id, :Trash, original_id)
    assert ActiveImap::ImapMessage.exists?(@record_id, :Inbox, new_id)
    
    message.delete!
    assert !ActiveImap::ImapMessage.exists?(@record_id, :Inbox, new_id)
  end
  
end
