class TestEncryption < Test::Unit::TestCase
  
  def test_001_key_generator
    TestHelper::Output.puts_test_log("Encryption key generator")
    
    5.times do
      str_length = rand(10000)
      assert ActiveMailbox::KeyGenerator.random_string(str_length).length == str_length
    end
    
    sha2_hash = ActiveMailbox::KeyGenerator.sha2_hash
    assert sha2_hash.length == 64
    
    [64, 128, 256, 512].each do |bitlength|
      assert ActiveMailbox::KeyGenerator.aes_key(sha2_hash, bitlength).length == (bitlength/8)
    end
  end
  
  def test_002_encrypt_decrypt
    TestHelper::Output.puts_test_log("Encryption encrypt/decrypt")
    
    str = "my_secret_password"
    
    sha2_hash = ActiveMailbox::KeyGenerator.sha2_hash
    aes_key = ActiveMailbox::KeyGenerator.aes_key(sha2_hash)
    
    encrypted_str = ActiveMailbox::AESEncryption.encrypt(aes_key, str)
    assert encrypted_str != str
    assert ActiveMailbox::AESEncryption.decrypt(aes_key, encrypted_str) == str
  end
  
end