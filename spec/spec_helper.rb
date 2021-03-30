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
