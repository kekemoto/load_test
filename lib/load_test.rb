# frozen_string_literal: true

require "etc"
require "async"

require_relative "load_test/version"
require_relative "load_test/future"
require_relative "load_test/stat"
require_relative "load_test/stat_row"

# load test
module LoadTest
  module_function

  # Run a load test.
  #
  # Note: Either limit_time or limit_count is required.
  #
  # rpm:: The number of times to execute the block per minute.
  # limit_time:: After this number of seconds, the test ends.
  # limit_count:: The test ends when the block executes limit_count times.
  # process_size:: Number of processes to launch. Default is equal to the number of CPU cores.
  # block {|result_sender| ... }:: This content is efficiently repeated in parallel. Argument is LoadTest::ResultSender.
  # return:: Enumerator[https://docs.ruby-lang.org/en/master/Enumerator.html]
  def run(rpm:, limit_time: nil, limit_count: nil, process_size: nil, &block)
    if limit_time.nil? && limit_count.nil?
      raise ArgumentError, "Either limit_time or limit_count is required."
    end

    process_size ||= Etc.nprocessors

    # request per second (per process)
    rps = (60 / rpm.to_f) * process_size

    # Number of requests per process.
    if limit_count
      base_request_count = limit_count.div(process_size)
      request_counts = Array.new(process_size, base_request_count)
      (limit_count % process_size).times { request_counts[_1] += 1 }
    else
      request_counts = Array.new(process_size, nil)
    end

    reader, writer = IO.pipe
    result_sender = LoadTest::ResultSender.new(writer)

    request_counts.each do |request_count|
      fork do
        reader.close
        error = nil

        catch do |finish|
          timers = Timers::Group.new

          timers.after(limit_time) { throw finish } if limit_time

          timers.every(rps) do
            block.call(result_sender)
          rescue => e
            error = e
            throw finish
          end

          if request_count
            request_count.times { timers.wait }
          else
            loop { timers.wait }
          end
        end

        raise error if error

      ensure
        writer.close
      end
    end

    writer.close
    Process.waitall

    result_receiver(reader)
  end

  # It executes while finely controlling computational resources.
  #
  # process_size:: The number of times to do {Process.fork}[https://docs.ruby-lang.org/en/master/Process.html#method-c-fork].
  # concurrent:: The meaning is close to the number of threads. It's strictly the number of Async[https://github.com/socketry/async].
  # repeat:: number of times to repeat. If nil is specified, it will loop infinitely.
  # block {|result_sender| ... }:: This content is efficiently repeated in parallel. Argument is LoadTest::ResultSender.
  # return:: Enumerator[https://docs.ruby-lang.org/en/master/Enumerator.html]
  def run_custom(process_size: nil, concurrent: 1, repeat: 1, interval: 0, &block)
    process_size ||= Etc.nprocessors
    reader, writer = IO.pipe
    result_sender = LoadTest::ResultSender.new(writer)

    process_size.times do
      fork do
        reader.close
        Async do |task|
          concurrent.times do
            task.async do
              if repeat
                repeat.times do
                  block.call(result_sender)
                  sleep interval
                end
              else
                loop do
                  block.call(result_sender)
                  sleep interval
                end
              end
            end
          end
        end
      ensure
        writer.close
      end
    end

    writer.close
    Process.waitall

    result_receiver(reader)
  end

  # Create an Enumerator that receives results from the child process.
  #
  # reader:: reader of IO.pipe
  # return:: Enumerator
  def result_receiver(reader) # :nodoc:
    Enumerator.new do |y|
      raise "This Enumerator can only be repeated once. hint: It may be better to use the Enumerator#to_a method to make it an array." if reader.closed?

      loop do
        break if reader.eof?
        result = Marshal.load(reader)
        raise result if result.is_a?(Exception)
        y << result
      end
    ensure
      reader.close
    end
  end

  # Send result to parent process.
  class ResultSender
    # Constructor.
    #
    # writer:: writer of IO.pipe
    def initialize(writer)
      @writer = writer
    end

    # Send result to parent process.
    #
    # data:: Marshalable[https://docs.ruby-lang.org/en/master/Marshal.html] object.
    def <<(data)
      Marshal.dump(data, @writer)
    end
  end

  # Statistics of load test results.
  def stat(result)
    LoadTest::Stat.load(result)
  end

  # Output statistics to stdout.
  def output_stdout(stat, columns: [:name, :average, :median, :percentile_80, :percentile_90, :count, :error_count], decimal_place: 2)
    columns.map!(&:to_s)
    column_to_values = columns.to_h { [_1, [_1]] }

    stat.to_a.sort_by(&:name).each do |stat_row|
      columns.each do |column|
        if /percentile/.match?(column)
          percent = column.split("_")[1]
          column_to_values[column] << stat_row.percentile(Integer(percent)).round(decimal_place).to_s
        else
          raise "Column '#{column}' does not exist." unless stat_row.respond_to?(column)
          result = stat_row.send(column)
          if result.is_a?(Numeric)
            result = result.round(decimal_place)
          end
          column_to_values[column] << result.to_s
        end
      end
    end

    column_to_size = column_to_values.transform_values do |values|
      values.max_by(&:size).size
    end

    column_to_values = column_to_values.transform_values { _1[1..] }

    puts columns.map {
      _1.ljust(column_to_size[_1])
    }.join(" | ")

    column_to_values.first[1].size.times do |index|
      puts columns.map { |column|
        column_to_values[column][index].rjust(column_to_size[column])
      }.join(" | ")
    end
  end
end
