# Statistics
class LoadTest::StatRow
  # name
  attr_accessor :name
  # Data array for statistics.
  attr_accessor :values
  # An array of errors.
  attr_accessor :errors

  # Constructor
  def initialize(name)
    @name = name
    @values = []
    @errors = []
  end

  # This method performs data relocation.
  # Call when you have finished entering data.
  def finish
    @values.sort!
  end

  # Calculate the average value.
  def average
    @values.sum / @values.size.to_f
  end

  # Calculate the percentile value.
  def percentile(value)
    index = (@values.size.pred * value / 100.0).round
    @values[index]
  end

  # Calculate the median value.
  def median
    percentile(50)
  end

  # Number of data used for statistics.
  def count
    @values.size
  end

  # number of errors.
  def error_count
    @errors.size
  end
end
