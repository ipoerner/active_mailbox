module TestRmailMbox
  
  #
  # Main fixtures test
  #
  
  def test_fixtures
    TestHelper::Output.puts_test_log("RMail fixtures")
    
    messages = read_mailbox(TestHelper::Fixtures.rmail_mbox)
    length = TestHelper::Fixtures.rmail_length
    
    # test total amount
    assert_equal(length, messages.length)
    
    # test messages individually
    # assertions are called in the same order as the messages appear in the mailbox
    assert_minimal_message(messages.shift)
    assert_charset_madness(messages.shift)
    assert_quoted_message(messages.shift)
    assert_html_message(messages.shift)
    assert_multipart_message(messages.shift)
  end
  
  #
  # Minimal message (not much to do here)
  #
  
  def assert_minimal_message(message)
    content_type = 'text/plain'
    charset      = 'us-ascii'
    
    assert !message.multipart?
    assert message.plaintext?
    assert !message.has_attachments?
    
    assert_equal(content_type, message.header.content_type)
    assert_equal(content_type, message.header.content_type_naive)
    assert_equal(charset, message.header.charset)
    assert_nil(message.header.content_disposition)
    assert_nil(message.header.content_disposition_naive)
  end
  
  #
  # Multiple content-type fields (example for folded header field)
  #
  
  def assert_charset_madness(message)
    content_type = 'plain'
    charset      = 'iso-8859-1'
    
    assert_equal(content_type, message.header.content_type)
    assert_equal(charset, message.header.charset)
    
    content_types = message.header.all_fields_with_params('content-type')
    assert_equal(2, content_types.length)
    
    m_content_type = content_types.last[:value].downcase
    m_charset      = content_types.last[:params]['charset'].downcase
    
    # old methods will only return first charset field specified
    assert_not_equal(m_content_type, message.header.content_type_naive)
    assert_not_equal(m_charset, message.header.charset_naive)
    
    # new methods should always return last field
    assert_equal(m_content_type, message.header.content_type)
    assert_equal(m_charset, message.header.charset)
  end
  
  #
  # Quoted-Printable Message
  #
  
  def assert_quoted_message(message)
    transfer_encoding = 'quoted-printable'
    special_chars     = "äöüß"
    
    assert_equal(transfer_encoding, message.header['content-transfer-encoding'])
    assert_not_nil message.header.unquoted_subject.index(special_chars)
    assert_not_nil message.header.unquoted_address("from").first.index(special_chars)
    assert_not_nil message.unquoted_body.index(special_chars)
  end
  
  #
  # HTML message with multiple content-type fields
  #
  
  def assert_html_message(message)
    content_type = 'html'
    charset      = 'windows-1252'
    
    assert_equal(content_type, message.header.content_type)
    assert_equal(charset, message.header.charset)
  end
  
  #
  # Multipart message with JPEG attachment
  #
  
  def assert_multipart_message(message)
    count       = 1
    disposition = "attachment"
    filename    = "attachment.jpg"
    type        = "image/jpeg"
    
    assert message.multipart?
    assert message.has_attachments?
    
    attachment = message.part(1)
    assert attachment.attachment?
    
    assert_equal(disposition, attachment.header.content_disposition)
    assert_equal(disposition, attachment.header.content_disposition_naive)
    assert_equal(filename, attachment.header.unquoted_filename)
    assert_equal(type, attachment.header.content_type)
    assert_equal(type, attachment.header.content_type_naive)

    attachments = message.attachments(false)
    assert_equal(count, attachments.length)
    
    attachment = attachments.shift
    assert_equal(disposition, attachment[:disposition])
    assert_equal(filename, attachment[:filename])
    assert_equal(type, attachment[:type])
  end
  
  private
  
  #
  # Parse fixtures with TMail and RMail
  #
  
  def read_mailbox(name)
    messages = []
    # tmail crashes on charset madness
    assert_raises(TMail::SyntaxError) {
      parse_mailbox_with_tmail(name) { |m| messages << m }
    }
    
    messages = []
    # rmail parser should not crash
    assert_nothing_raised {
      parse_mailbox_with_rmail(name) { |m| messages << m }
    }
    
    messages
  end
  
  def parse_mailbox_with_rmail(mailbox_file)
    File.open(mailbox_file) { |mailbox|
      RMail::Mailbox.parse_mbox(mailbox).each { |msg_string|
        yield RMail::Parser.read(msg_string)
      }
    }
  end
  
  def parse_mailbox_with_tmail(mailbox_file)
    mailbox = TMail::UNIXMbox.new(mailbox_file, nil, true)
    mailbox.each_port { |port|
      yield TMail::Mail.new(port)
    }
  end
  
end

class TestRmailExtensions < Test::Unit::TestCase
  
  include TestRmailMbox
  
  #
  # Add an attachment to new message
  #
  
  def test_add_attachment
    TestHelper::Output.puts_test_log("RMail add attachment")
    
    text_parts = [ "Test Message Part 1", "Test Message Part 2" ]
    
    message = RMail::Message.new
    message.body = text_parts[0]
    assert !message.multipart?
    assert !message.has_attachments?
    
    message.add_part(text_parts[1])
    assert message.multipart?
    assert !message.has_attachments?
    assert_equal(0,message.attachments.length)
    
    message.add_attachment("", "")
    assert message.multipart?
    assert message.has_attachments?
  end
  
  #
  # Get attachment from message
  #
  
  def test_get_attachment
    TestHelper::Output.puts_test_log("RMail get attachment")
    
    count    = 1
    filename = "test.txt"
    content  = "test"
    
    message = RMail::Message.new
    
    message.add_attachment(filename, content)
    assert_equal(count, message.attachments.length)
    
    # do not get actual file data
    attachment = message.attachments.shift
    assert_equal(filename, attachment[:filename])
    assert_equal("", attachment[:content])
    
    # also get file data
    attachment = message.attachments(false).shift
    assert_equal(content, attachment[:content])
  end
  
  #
  # Message responds to custom methods
  #
  
  def test_respond_to
    TestHelper::Output.puts_test_log("RMail respond_to")
    
    native_methods     = [ :subject, :from, :to, :cc, :bcc ]
    custom_methods     = [ :charset, :content_type, :content_disposition, :filename ]
    unquoted_methods   = RMail::Header::UNQUOTED_METHODS
    unsupported_method = :unquoted_blah
    
    message = RMail::Message.new
    
    native_methods.each do |method_id|
      assert(message.header.respond_to?(method_id))
    end

    custom_methods.each do |method_id|
      assert(message.header.respond_to?(method_id))
    end
    
    unquoted_methods.each do |method_id|
      method_id = "unquoted_#{method_id.to_s}".to_sym
      assert(message.header.respond_to?(method_id))
    end
    
    # this method is not supported
    assert(!message.header.respond_to?(unsupported_method))
    assert_raises(NoMethodError) { message.header.send(unsupported_method) }
  end
  
  #
  # Custom "unquoted_*" methods work as expected
  #
  
  def test_custom_methods
    TestHelper::Output.puts_test_log("RMail custom methods")
    
    message = RMail::Message.new
    assert_nil(message.header.unquoted_subject)
    assert_nil(message.header.unquoted_filename)
    assert_equal([], message.header.unquoted_address("from"))
    assert_nil(message.header.unquoted_field("subject"))
  end
  
end
