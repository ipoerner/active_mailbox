module ActiveMailbox
  
  # Bitlength of the AES keys.
  
  ENCRYPTION_BITLENGTH = 256
  
  # This class can be used to generate various kinds of keys.
  
  class KeyGenerator
    
    # Characters used to generate a random string.
    
    STANDARD_CHARS = ["a".."z", "A".."Z", "0".."9"].collect { |range| range.to_a }.flatten
    
    class << self
      
      # Create a SHA-2 hash using the OpenSSL library.
      
      def sha2_hash
        str = random_string(2048)
        hashfunc = OpenSSL::Digest::SHA256.new
        hashfunc.update(str)
        hashfunc.hexdigest
      end
      
      # Create a pseudo-random string of length +len+.
      
      def random_string(len)
        (1..len).to_a.collect { |i| STANDARD_CHARS[rand(STANDARD_CHARS.length)] }.join
      end
      
      # Create an AES key with +bitlength+ number of bits, based on a secret key +key+.
      
      def aes_key(key, bitlength = ENCRYPTION_BITLENGTH)
        key.unpack('a2' * (bitlength/8)).map{|x| x.hex}.pack('c*')
      end
      
    end
  
  end
  
  # Used for easy encryption and decryption of data using a secret key and the OpenSSL AES implementation.

  class AESEncryption
    
    CIPHER = "AES-#{ENCRYPTION_BITLENGTH}-CBC" #:nodoc:
    
    class << self
      
      # Encrypt a string +str+ using the secret key +key+.
    
      def encrypt(key, str)
        cipher = OpenSSL::Cipher::Cipher.new(CIPHER)
        cipher.encrypt
        cipher.key = key
        
        pack(cipher.update(str) + cipher.final)
      end
      
      # Decrypt a string +str+ using the secret key +key+.
      
      def decrypt(key, str)
        cipher = OpenSSL::Cipher::Cipher.new(CIPHER)
        cipher.decrypt
        cipher.key = key
        
        cipher.update(unpack(str)) + cipher.final
      end
      
      private
      
      BLOCK_LENGTH = 2  #:nodoc:
      UNPACK_STR = "C*"  #:nodoc:
      PACK_STR = "a#{BLOCK_LENGTH}"  #:nodoc:
      
      def pack(str)
        l = str.length
        str.unpack(UNPACK_STR).map{|x| x.to_s(16).rjust(BLOCK_LENGTH,"_")}.pack(PACK_STR*l)
      end
      
      def unpack(str)
        l = str.length/BLOCK_LENGTH
        str.unpack(PACK_STR*l).map{|x| x.strip_char("_").to_i(16)}.pack(UNPACK_STR)
      end
      
    end
    
  end
  
end
