module TestFolder
  
  # The upper limit was chosen with UW-IMAP in mind, where you are allowed to create and subscribe
  # to folders that won't possibly appear in a LIST response afterwards. Will keep that out of the
  # UW-IMAP driver until I'm positive this is not just a coincidence.
  
  DEEP_HIERARCHY = 21
  
  # Find Inbox and Root folders.
  
  def test_folder001_find_basic_folders
    TestHelper::Output.puts_test_log("some basic find calls")
    
    assert ActiveImap::ImapFolder.exists?(@record_id, :Inbox)
    assert ActiveImap::ImapFolder.exists?(@record_id, :Root)
    
    inbox = ActiveImap::ImapFolder.find(@record_id, :Inbox)
    assert inbox.name_is?("INBOX")
    
    root = ActiveImap::ImapFolder.find(@record_id, :Root)
    assert root.name_is?("")
    assert root.subfolders?
  end
  
  # Attempt to create a folder under an invalid pathname.
  
  def test_folder002_create_invalid_folder
    TestHelper::Output.puts_test_log("create invalid folder")
    
    prefix = TestHelper::Fixtures.folder(@record_id, :protected)
    
    path = "#{prefix}invalid_folder"
    
    assert_raise(ActiveMailbox::Errors::FolderCreationNotPermitted) {
      ActiveImap::ImapFolder.create(@record_id, path)
    }
  end
  
  # Create at least one folder and one subfolder and then attempt to remove
  # the parent folder with and without the :recursive option.
  
  def test_folder003_recursive_delete
    TestHelper::Output.puts_test_log("recursive delete")
    
    delim  = TestHelper::Fixtures.delimiter(@record_id)
    prefix = TestHelper::Fixtures.folder(@record_id, :writeable)
    
    root_path = "#{prefix}my_folder"
    path      = root_path + "#{delim}foo"
    
    # initial cleanup
    begin
      ActiveImap::ImapFolder.delete(@record_id, root_path, :recursive => true)
    rescue
    end
    
    # create folder
    begin
      # only recursively created folders can definetely be removed recursively
      ActiveImap::ImapFolder.create(@record_id, path, :recursive => true)
    rescue
      # most probably no inferiors allowed or folder path too deep
      begin
        ActiveImap::ImapFolder.delete(@record_id, root_path, :recursive => true)
      rescue
      end
      return
    end
    
    # check if folder has really been created
    foo = ActiveImap::ImapFolder.find(@record_id, path)
    assert  foo.instance_of?(ActiveImap::ImapFolder)
    assert  foo.path_is?(path) && foo.name_is?("foo")
    
    # attempt remove
    assert_raise(ActiveMailbox::Errors::FolderRemovalNotPermitted) {
      ActiveImap::ImapFolder.delete(@record_id, root_path)
    }
    assert_nothing_raised {
      ActiveImap::ImapFolder.delete(@record_id, root_path, :recursive => true)
    }
  end
  
  # Create multiple folders so that the maximum depth for this server is <i>almost</i> reached.
  # Add one more subfolder to the tree after that and check whether an exception is raised.
  
  def test_folder004_max_folder_depth
    TestHelper::Output.puts_test_log("create max. inferiors")
    
    delim         = TestHelper::Fixtures.delimiter(@record_id)
    prefix        = TestHelper::Fixtures.folder(@record_id, :writeable)
    depth_limit   = TestHelper::Fixtures.folder_depth_limit(@record_id)
    minimum_depth = (prefix.empty?) ? 1 : 2
    
    return unless (depth_limit.nil? || depth_limit >= minimum_depth)
    
    create_inferiors = depth_limit || DEEP_HIERARCHY
    create_inferiors -= 1 unless (prefix.empty?)  # another folder prefixes path
    create_inferiors -= 1 # "my_folder" already contained
    
    create_inferiors = 0 if create_inferiors < 0
    
    root_path = "#{prefix}my_folder"
    path = root_path + ("#{delim}foo" * create_inferiors)
    
    # initial cleanup
    begin
      ActiveImap::ImapFolder.delete(@record_id, root_path, :timeout => 30.seconds, :recursive => true)
      ActiveImap::ImapFolder.delete(@record_id, "Trash.foo", :timeout => 30.seconds, :recursive => true)
    rescue
    end
    
    # attempt to create a folder at the limit of what is allowed
    begin
      ActiveImap::ImapFolder.create(@record_id, path, :timeout => 30.seconds)
    rescue ActiveMailbox::Errors::FolderCreationNotPermitted
      return
    end
    
    # do cleanup
    begin
      ActiveImap::ImapFolder.delete(@record_id, root_path, :timeout => 30.seconds)
    rescue
      # some servers do not automatically remove parents - attempt manual remove
      ActiveImap::ImapFolder.delete(@record_id, path, :timeout => 30.seconds, :recursive => true)
    end
    
    # create a folder that is nested too deep
    unless depth_limit.nil?
      assert_raise(ActiveMailbox::Errors::FolderCreationNotPermitted) {
        ActiveImap::ImapFolder.create(@record_id, (path + "#{delim}foo"))
      }
    end
    
  end
  
  # Create a folder and move it to another path, then make a change to its subscription.
  
  def test_folder005_update_folders
    TestHelper::Output.puts_test_log("update folder")
    
    delim         = TestHelper::Fixtures.delimiter(@record_id)
    prefix        = TestHelper::Fixtures.folder(@record_id, :writeable)
    depth_limit   = TestHelper::Fixtures.folder_depth_limit(@record_id)
    minimum_depth = (prefix.empty?) ? 1 : 2
    
    return unless (depth_limit.nil? || depth_limit >= minimum_depth)
    
    original_path = prefix
    new_path      = prefix
    if depth_limit.nil? || depth_limit > minimum_depth
      # adds another level
      original_path += "my_folder#{delim}"
      new_path      += "my_folder#{delim}"
    end
    original_path += "old_path"
    new_path      += "new_path"
    
    # initial cleanup
    begin
      ActiveImap::ImapFolder.delete(@record_id, original_path)
    rescue
    end
    begin
      ActiveImap::ImapFolder.delete(@record_id, new_path)
    rescue
    end
    
    # attempt to create folder
    begin
      ActiveImap::ImapFolder.create(@record_id, original_path)
    rescue ActiveMailbox::Errors::FolderCreationNotPermitted
      # not permitted for whatever reason - test not possible
      return
    end
    
    assert ActiveImap::ImapFolder.exists?(@record_id, original_path)
    
    assert_nothing_raised {
      ActiveImap::ImapFolder.update(@record_id, original_path, :path => new_path)
      assert  ActiveImap::ImapFolder.exists?(@record_id, new_path)
      assert !ActiveImap::ImapFolder.exists?(@record_id, original_path)
    }
    
    # FIXME:
    # doesn't work very well, as some servers do not support subscribe/unsubscribe while
    # others take a long time to update subscription status (fixed?)
#    assert_nothing_raised {
#      ActiveImap::ImapFolder.update(@record_id, new_path, :subscription => false)
#      assert !ActiveImap::ImapFolder.exists?(@record_id, new_path)
#    }
    
    assert_nothing_raised {
      ActiveImap::ImapFolder.delete(@record_id, new_path)
    }
    
  end
  
  # Create a folder with two subfolders
  
  def test_folder006_folder_cache
    TestHelper::Output.puts_test_log("recursive delete 2")
    
    delim  = TestHelper::Fixtures.delimiter(@record_id)
    prefix = TestHelper::Fixtures.folder(@record_id, :writeable)
    
    root_path = "#{prefix}my_folder"
    foo_path  = root_path + "#{delim}foo"
    bar_path  = root_path + "#{delim}bar"
    
    # initial cleanup
    begin
      ActiveImap::ImapFolder.delete(@record_id, root_path, :recursive => true)
    rescue
    end
    
    # attempt to create folders
    begin
      # only recursively created folders can definetely be removed recursively
      ActiveImap::ImapFolder.create(@record_id, foo_path, :recursive => true)
      ActiveImap::ImapFolder.create(@record_id, bar_path, :recursive => true)
      ActiveImap::ImapFolder.update(@record_id, bar_path, :subscription => false)
    rescue
      # most probably no inferiors allowed or folder path too deep
      begin
        ActiveImap::ImapFolder.delete(@record_id, root_path, :recursive => true)
      rescue
      end
      return
    end
    
    # get root dir, remove root dir
    assert_nothing_raised {
      ActiveImap::ImapFolder.find(@record_id, root_path)
    }
    assert_nothing_raised {
      ActiveImap::ImapFolder.delete(@record_id, root_path, :recursive => true)
    }
  end
  
  def test_folder007_read_folders
    TestHelper::Output.puts_test_log("get messages from folder")
    
    inbox = ActiveImap::ImapFolder.find(@record_id, :Inbox)
    assert inbox.instance_of?(ActiveImap::ImapFolder)
    
    begin
      message = inbox.messages(:command => ["1"])  # get the first message
      assert message.instance_of?(ActiveImap::ImapMessage)
    rescue ActiveMailbox::Errors::MessageNotFound
      return
    end
  end
  
  def test_folder008_update_folder
    TestHelper::Output.puts_test_log("update folder 2")
    
    delim         = TestHelper::Fixtures.delimiter(@record_id)
    prefix        = TestHelper::Fixtures.folder(@record_id, :writeable)
    depth_limit   = TestHelper::Fixtures.folder_depth_limit(@record_id)
    minimum_depth = (prefix.empty?) ? 1 : 2
    
    return unless (depth_limit.nil? || depth_limit >= minimum_depth)
    
    original_path = prefix
    new_path      = prefix
    if depth_limit.nil? || depth_limit > minimum_depth
      # adds another level
      original_path += "my_folder#{delim}"
      new_path      += "my_folder#{delim}"
    end
    original_path += "old_path"
    new_path      += "new_path"
    
    # initial cleanup
    begin
      ActiveImap::ImapFolder.delete(@record_id, original_path)
    rescue
    end
    begin
      ActiveImap::ImapFolder.delete(@record_id, new_path)
    rescue
    end
    
    assert_nothing_raised {
      ActiveImap::ImapFolder.create(@record_id, original_path)
    }
    
    folder = ActiveImap::ImapFolder.find(@record_id, original_path)
    
    folder.name = "new_path"
    folder.save!
    
    assert (folder.location == new_path)
    
    assert_nothing_raised {
      ActiveImap::ImapFolder.find(@record_id, new_path)
    }
    
    folder.subscription = false
    folder.save!
    
    assert_nothing_raised {
      ActiveImap::ImapFolder.delete(@record_id, new_path, :recursive => true)
    }
  end
  
end
