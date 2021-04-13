# frozen_string_literal: true

require_relative "lib/cutlass/version"

Gem::Specification.new do |spec|
  spec.name = "cutlass"
  spec.version = Cutlass::VERSION
  spec.authors = ["schneems"]
  spec.email = ["richard.schneeman+foo@gmail.com"]

  spec.summary = "Write CNB integration tests for Pack in Ruby with cutlass"
  spec.description = "Have you ever had problems opening a `pack` age? Try something sharper, try CUTLASS!"
  spec.homepage = "https://github.com/heroku/cutlass"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/heroku/cutlass"
  spec.metadata["changelog_uri"] = "https://github.com/heroku/cutlass/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "docker-api", ">= 2.0"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
