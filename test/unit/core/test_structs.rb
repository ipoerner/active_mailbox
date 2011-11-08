class TestStructs < Test::Unit::TestCase
  
  def test_001_imap_path
    TestHelper::Output.puts_test_log("Structs IMAP path")
    
    path = "Inbox.Trash"
    delimiter = "."
    
    imap_path = ActiveMailbox::Base::ImapPath.new(path, delimiter)
    assert imap_path.path == path
    assert imap_path.name_is?("Trash")
    assert imap_path.name_is?("TRASH")
    assert imap_path.path_is?("Inbox.Trash")
    assert imap_path.path_is?("inbox.trash")
    assert imap_path.path_is?("INBOX.Trash")
    assert imap_path.path_is?("INBOX.TRASH")
    
    parent_path = imap_path.parent_path
    assert parent_path == "Inbox"
    parent = ActiveMailbox::Base::ImapPath.new(parent_path, delimiter)
    
    subfolder_path = imap_path.subfolder_path("blub")
    assert subfolder_path == "Inbox.Trash.blub"
    subfolder = ActiveMailbox::Base::ImapPath.new(subfolder_path, delimiter)
    
    assert imap_path.superior_to?(subfolder)
    assert imap_path.parent_of?(subfolder)
    assert parent.superior_to?(imap_path)
    assert parent.parent_of?(imap_path)
    assert parent.superior_to?(subfolder)
    assert !parent.parent_of?(subfolder)
  end
  
end