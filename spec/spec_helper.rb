# frozen_string_literal: true

require "cutlass"
require "securerandom"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    Cutlass::CleanTestEnv.record
  end

  config.after(:suite) do
    Cutlass::CleanTestEnv.check
  end
end

def run!(command)
  out = `#{command}`
  raise "Command #{command} failed #{out}" unless $?.success?
  out
end

def with_stub_buildpack
  Dir.mktmpdir do |dir|
    dir = Pathname(dir)
    name = SecureRandom.hex(10)

    dir.join("package.toml").write(<<~EOM)
      [buildpack]
      uri = "."
    EOM
    dir.join("buildpack.toml").write(<<~EOM)
      api = "0.6"

      [buildpack]
      id = "cutlass/supreme_#{name}"
      version = "0.0.1"

      [[stacks]]
      id = "io.buildpacks.stacks.bionic"

      [[stacks]]
      id = "heroku-18"

      [[stacks]]
      id = "heroku-20"
    EOM

    dir.join("bin/detect").tap do |file|
      file.dirname.mkpath
      file.write(<<~EOM)
        #!/usr/bin/env bash

        exit 0
      EOM

      FileUtils.chmod("+x", file)
    end

    dir.join("bin/build").tap do |file|
      file.write(<<~EOM)
        #!/usr/bin/env bash

        exit 0
      EOM

      FileUtils.chmod("+x", file)
    end

    local_buildpack = Cutlass::LocalBuildpack.new(directory: dir)
    local_buildpack.call
    yield local_buildpack
  ensure
    local_buildpack&.teardown
  end
end

def default_heroku_builder
  "heroku/builder:18"
end
