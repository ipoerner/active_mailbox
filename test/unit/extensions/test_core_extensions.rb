module TestStringExtensions
  
  def test_string_strip_char
    TestHelper::Output.puts_test_log("String strip_char")
    
    str = "....blah.."
    assert str.strip_char(".") == "blah"
    
    str = "/folder_path/blah///"
    assert str.strip_char("/") == "folder_path/blah"
    
    str = "   ..blubber "
    assert str.strip_char(" ") == "..blubber"
    
    assert str.strip_char(" ") == "..blubber"
    
    assert str.strip_char(".") != "..blubber"
  end
  
end

module TestNumericExtensions
  
  def test_numeric_bytes_to_str
    TestHelper::Output.puts_test_log("Numberic bytes_to_str")
    
    assert_numeric(0, 0)
    
    for multiplier in 0..6 do
      range = (1024**multiplier)...(1024**(multiplier+1))
      range.step(range.last/8) do |i|
        assert_numeric(i, multiplier)
      end
    end
  end
  
  private
  
  def assert_numeric(value, multiplier)
    short_value = value / (1024**multiplier)
    
    short, long = case multiplier
      when 0
        ["Byte", "Byte(s)"]
      when 1
        ["Kb", "Kilobyte(s)"]
      when 2
        ["Mb", "Megabyte(s)"]
      when 3
        ["Gb", "Gigabyte(s)"]
      when 4
        ["Tb", "Terabyte(s)"]
      when 5
        ["Pb", "Petabyte(s)"]
      when 6
        ["Eb", "Exabyte(s)"]
    end
    
    assert value.bytes_to_str        == "#{short_value} #{short}"
    assert value.bytes_to_str(false) == "#{short_value} #{long}"
  end
  
end

module TestArrayExtensions
  
  def test_array_shuffle
    TestHelper::Output.puts_test_log("Array shuffle")
    
    a = (1..4096).to_a
    b = a.shuffle
    
    assert b != a
    assert b.sort == a.sort
    
    assert a.shuffle! == a
    assert a.sort     != a
  end
  
end

module TestHashExtensions
  
  def test_hash_valid_keys
    TestHelper::Output.puts_test_log("Hash valid keys")
    
    valid_keys = [:a, :b, :c]
    h = { :a => "blah", :b => "blah", :c => "blah" }
    
    assert_nothing_raised {
      h.assert_valid_keys(valid_keys)
    }
    
    h[:d] = "blah"
    
    error = assert_raise(ArgumentError) {
      h.assert_valid_keys(valid_keys)
    }
    
    assert error.message == "Invalid key(s): d"
  end
  
  def test_hash_reverse_merge
    TestHelper::Output.puts_test_log("Hash reverse_merge")
    
    default_options = { :a => 100, :b => 200, :c => 300 }
    options = { :a => 50, :d => 500 }
    
    assert options.reverse_merge(default_options) == default_options.merge(options)

    options.reverse_merge!(default_options)
    assert options == default_options.merge(options)
    
    assert options[:a] == 50
    assert options[:b] == 200
    assert options[:c] == 300
    assert options[:d] == 500
  end
  
end

class TestCoreExtensions < Test::Unit::TestCase
  
  include TestStringExtensions
  include TestNumericExtensions
  include TestArrayExtensions
  include TestHashExtensions
  
end
