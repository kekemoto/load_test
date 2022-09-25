require "pathname"
require "async"

class TestRunner
  def initialize
    ruby_texts = parse_document
    tests = ruby_texts.map{ Test.new(_1) }
    tests.shuffle.each(&:run)
  end

  def parse_document
    result = []
    ruby_text = nil

    path = Pathname(__dir__) + "../README.md"
    File.read(path).split("\n").each.with_index(1) do |text, line|
      if text.start_with?("```ruby")
        ruby_text = RubyText.new(path, line + 1)
      elsif text.start_with?("```") && ruby_text
        result << ruby_text
        ruby_text = nil
      elsif ruby_text
        ruby_text.add text
      end
    end

    result
  end

  class RubyText
    attr_reader :path, :start_line

    def initialize(path, start_line)
      @path = path
      @start_line = start_line
      @texts = []
    end

    def add(text)
      @texts << text
    end

    def to_s
      @texts.join("\n")
    end
  end

  class Test
    def initialize(ruby_text)
      @ruby_text = ruby_text
    end

    def run
      tmp = $stdout
      $stdout = StringIO.new("", "w")
      eval(@ruby_text.to_s, binding, @ruby_text.path.to_s, @ruby_text.start_line) # standard:disable all
      $stdout = tmp
      $stdout.print("\e[32m.\e[0m")
    rescue => e
      warn("\e[31m#{e.full_message}\e[0m")
    end
  end
end
