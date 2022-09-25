# Statistics are taken from the load test results.
class LoadTest::Stat
  include Enumerable

  def self.load(result) # :nodoc:
    this = new
    result.each do
      this.add(_1)
    end
    this.finish
    this
  end

  # Constructor of LoadTest::Stat
  #
  # block {|stat| ... }:: Data entry within the block. The argument is LoadTest::Stat.
  # return:: LoadTest::Stat
  def self.start(&block)
    this = new
    block.call this
    this.finish
    this
  end

  def initialize # :nodoc:
    @rows = Hash.new { |h, k| h[k] = LoadTest::StatRow.new(k) }
  end

  # Enter data for aggregation.
  #
  # hash1 and hash2 are the same.
  #
  #   {
  #     name: Aggregate field name,
  #     value: The value you want to stat, such as speed,
  #     error: If you get an error,
  #   }
  def add(hash1 = nil, **hash2)
    hash = hash1 || hash2

    if hash.key?(:value)
      @rows[hash[:name]].values << hash[:value]
    end

    if hash.key?(:error)
      @rows[hash[:name]].errors << hash[:error]
    end
  end

  # This method performs data relocation.
  # Call when you have finished entering data.
  # If you are using LoadTest::Stat.start or LoadTest::Stat.load, it will be done automatically.
  def finish
    @rows.values.each(&:finish)
  end

  # Repeat LoadTest::StatRow.
  def each(...)
    @rows.values.each(...)
  end
end
