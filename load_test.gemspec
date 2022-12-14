# frozen_string_literal: true

require_relative "lib/load_test/version"

Gem::Specification.new do |spec|
  spec.name = "load_test"
  spec.version = LoadTest::VERSION
  spec.authors = ["kekemoto"]
  spec.email = ["kekemoto.hp@gmail.com"]

  spec.summary = "Load Test for Rubyist."
  spec.description = "A simple and easy load test library."
  spec.homepage = "https://github.com/kekemoto/load_test"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  # spec.metadata["allowed_push_host"] = "https://github.com/kekemoto/load_test"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/kekemoto/load_test.git"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "async", "~> 2.0"
  spec.add_dependency "timers", "~> 4.3"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
