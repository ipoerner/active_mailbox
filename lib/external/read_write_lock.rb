require "thread"

# ReadWriteLock is a lock that allows many readers or one writer
# A writer must wait until there are zero readers and zero writers
# A reader must wait until there are zero writers
#
# Example:
#
#   lock = ReadWriteLock.new
#   lock.read do
#     # readers may acquire the lock while we are in this block; writers may not
#   end
#   lock.write do
#     # neither readers nor writers may acquire the lock while we are in this block
#   end
#
# Original by Jonah Burke <blog.jonahb.com>
#
# Mutex_m patch by Ingmar Poerner (09/02/24)
#
# block/unblock patch by Ingmar Poerner (09/06/24)
#

class ReadWriteLock

  def initialize
    # there is ((one or more readers) or (one writer)) iff @reader_mutex is locked
    @reader_mutex = Object.new
    @reader_mutex.extend(Mutex_m)

    # there is one writer iff @writer_mutex is locked
    @writer_mutex = Object.new
    @writer_mutex.extend(Mutex_m)

    # the number of readers
    @reader_count = 0

    # we must acquire lock on @reader_count_mutex before reading or writing @reader_count
    @reader_count_mutex = Object.new
    @reader_count_mutex.extend(Mutex_m)
    
    # no new readers or writers allowed while @blocked == true
    @blocked = false
    
    @blocked_mutex = Object.new
    @blocked_mutex.extend(Mutex_m)
  end
  
  def read(&block)
    begin
      start_read
      yield
    ensure
      end_read
    end
  end  

  def write(&block)
    begin
      start_write
      yield
    ensure
      end_write
    end
  end
  
  def block!(&block)
    begin
      start_block
      yield
    ensure
      end_block
    end
  end
  
  def writer?
    @writer_mutex.locked?
  end
  
  def reader_count
    @reader_count
  end    
  
  private
  
  def start_read
    @blocked_mutex.synchronize do
      raise Exception if @blocked
    end
    @reader_count_mutex.synchronize do
      if @reader_count == 0
        @reader_mutex.lock
      end
      @reader_count = @reader_count + 1
    end
    self
  end

  def end_read
    @reader_count_mutex.synchronize do
      if @reader_count > 0
        @reader_count = @reader_count - 1
        if @reader_count == 0
          @reader_mutex.unlock
        end
        self
      else
        raise ThreadError, "end_read called when there are no readers"
      end
    end
  end

  def start_write
    @blocked_mutex.synchronize do
      raise Exception if @blocked
    end
    @writer_mutex.lock
    @reader_mutex.lock
    self
  end

  def end_write
    if @writer_mutex.unlock
      @reader_mutex.unlock
      self
    else
      raise ThreadError, "end_write called when there is no writer"
    end
  end
  
  def start_block
    @blocked_mutex.synchronize do
      @blocked = true
    end
  end
  
  def end_block
    @blocked_mutex.synchronize do
      @blocked = false
    end
  end
  
end