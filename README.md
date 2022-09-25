# Load Test for Rubyist

```ruby
require "load_test"
require "net/http" # This is standard library.
require "benchmark" # This is standard library.

result = LoadTest.run(rpm: 2000, limit_time: 5) do |result|
  uri = URI.parse("http://localhost")
  time = Benchmark.realtime { Net::HTTP.get_response(uri) }
  result << { name: uri.to_s, value: time }
end

stat = LoadTest.stat(result)
LoadTest.output_stdout(stat)

# => name             | average | median | percentile_80 | percentile_90 | count | error_count
# => http://localhost |    1.78 |   2.01 |          3.01 |          3.02 |    34 |           0
```

## Feature

- Write in ruby.
- It's a library, not a command, for simplicity.
  - No need to learn scenario files.
  - Just run the ruby file.
  - Loop and branch at will.
  - Parallel execution, serial execution, deferred execution, whatever you want.
  - You can use it without HTTP.
  - It's flexible yet simple.
- Efficient load testing with multiple processes and asynchronous IO with the {Async gem}[https://github.com/socketry/async].

## Installation

Add this line to your application's Gemfile:

```
gem 'load_test'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install load_test

## API Document

TODO

## Example: error handling

```ruby
require "load_test"
require "net/http"
require "benchmark"

result = LoadTest.run(rpm: 2000, limit_time: 5) do |result|
  uri = URI.parse("http://localhost")
  error = nil
  time = Benchmark.realtime do
    response = Net::HTTP.get_response(uri)
    error = response if response.code != "200"
  end

  if error
    result << { name: uri.to_s, error: error }
  else
    result << { name: uri.to_s, value: time }
  end
end

stat = LoadTest.stat(result)
LoadTest.output_stdout(stat)
```

## Example: serial execution

```ruby
require "load_test"
require "net/http"
require "benchmark"

result_a = LoadTest.run(rpm: 2000, limit_time: 5) do |result|
  uri = URI.parse("http://localhost/a")
  time = Benchmark.realtime { Net::HTTP.get_response(uri) }
  result << { name: uri.to_s, value: time }
end

result_b = LoadTest.run(rpm: 2000, limit_time: 5) do |result|
  uri = URI.parse("http://localhost/b")
  time = Benchmark.realtime { Net::HTTP.get_response(uri) }
  result << { name: uri.to_s, value: time }
end

# Concatenate the results.
stat = LoadTest.stat(result_a + result_b)
LoadTest.output_stdout(stat)
```

## Example: parallel execution

```ruby
require "load_test"
require "net/http"
require "benchmark"

future_a = LoadTest::Future.new do
  LoadTest.run(rpm: 2000, limit_time: 5) do |result|
    uri = URI.parse("http://localhost/a")
    time = Benchmark.realtime { Net::HTTP.get_response(uri) }
    result << { name: uri.to_s, value: time }
  end.to_a
end

future_b = LoadTest::Future.new do
  LoadTest.run(rpm: 2000, limit_time: 5) do |result|
    uri = URI.parse("http://localhost/b")
    time = Benchmark.realtime { Net::HTTP.get_response(uri) }
    result << { name: uri.to_s, value: time }
  end.to_a
end

result_a = future_a.take
result_b = future_b.take

stat = LoadTest.stat(result_a + result_b)
LoadTest.output_stdout(stat)
```

## Example: options for execution.

```ruby
require "load_test"
require "net/http"
require "benchmark"

result = LoadTest.run_custom(concurrent: 1, process_size: 1, repeat: 1, interval: 0) do |result|
  uri = URI.parse("http://localhost")
  time = Benchmark.realtime { Net::HTTP.get_response(uri) }
  result << { name: uri.to_s, value: time }
end

stat = LoadTest.stat(result)
LoadTest.output_stdout(stat)
```

## Example: custom stat

```ruby
require "load_test"

result = LoadTest.run(rpm: 2000, limit_count: 10) do |result|
  result << {name: :rand, value: rand(1..10)}
end

stat = LoadTest.stat(result)
LoadTest.output_stdout(stat)
```

```ruby
require "load_test"

result = LoadTest.run(rpm: 2000, limit_count: 10) do |result|
  result << rand(1..10)
end

stat = LoadTest::Stat.start do |stat|
  result.each do |value|
    stat.add(name: :rand, value: value)
  end
end
LoadTest.output_stdout(stat)
```

## Example: custom output format

```ruby
require "load_test"
require "csv"

result = LoadTest.run(rpm: 2000, limit_count: 10) do |result|
  result << {name: :rand, value: rand(1..10)}
end

stat = LoadTest.stat(result)

CSV.open("./result.csv", "wb") do |csv|
  csv << ["name", "average", "median", "90 percentile", "99 percentile", "error_count"]
  stat.each do
    csv << [_1.name, _1.average, _1.median, _1.percentile(90), _1.percentile(99), _1.error_count]
  end
end
```

# Example: More freedom to stat!

`result` is just an [Enumerator](https://docs.ruby-lang.org/en/master/Enumerator.html).

```ruby
require "load_test"

result = LoadTest.run(rpm: 2000, limit_count: 10) do |result|
  result << rand(1..10)
end

result = result.to_a
min, max = result.minmax
total = result.sum
puts "total: #{total}, min: #{min}, max: #{max}"
pp result
```

## Note

LoadTest is run using a [process](https://docs.ruby-lang.org/en/master/Process.html#method-c-fork), so be careful with the scope.

```ruby
require "load_test"

# Bad
count = 0
LoadTest.run_custom(process_size: 2, concurrent: 1, repeat: 2) do
  count += 1
  pp count
end
# => 1
# => 1

pp count
# => 0
```

```ruby
require "load_test"

# Good
result = LoadTest.run_custom(process_size: 2, concurrent: 1, repeat: 2) do |result|
  result << 1
end

pp result.to_a.size
# => 2
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kekemoto/load_test.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
