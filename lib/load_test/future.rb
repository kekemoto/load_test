# Make parallelism by processes manageable.
class LoadTest::Future
  # process id
  attr_reader :pid
  # reader of IO.pipe
  attr_reader :reader

  class << self
    # Get the first completed future.
    def race(futures)
      hash = futures.to_h { [_1.reader, _1] }
      readers, = IO.select(futures.map(&:reader))
      hash[readers[0]]
    end

    # Wait until all futures have completed.
    def all(futures)
      futures.each(&:wait)
    end
  end

  # Execute the processing of the block asynchronously.
  def initialize(&block)
    reader, writer = IO.pipe

    @pid = fork do
      reader.close
      begin
        result = block.call
      rescue => e
        result = e
      end
      Marshal.dump(result, writer)
    end
    writer.close

    @reader = reader
    @is_done = false
  end

  # Wait for the process to complete.
  def wait
    return if @is_done
    Process.waitpid(@pid)
    @is_done = true
    self
  end

  # Wait until the process is completed and return the result.
  def take
    wait
    result = Marshal.load(@reader)
    @reader.close
    raise result if result.is_a?(Exception)
    result
  end

  # Abort the future.
  def abort
    Process.kill(:INT, @pid)
    @reader.close
    @is_done = true
  end
end
