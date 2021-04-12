# frozen_string_literal: true

require_relative "env_diff"
require_relative "docker_diff"

module Cutlass
  # Ensure that your environment variables and docker images aren't leaking in tests
  #
  # Docker image leaking is disabled by default in development. Set CUTLASS_CHECK_DOCKER
  # in CI.
  #
  #   CleanTestEnv.record
  #   CleanTestEnv.check(docker: true)
  #   # => nil
  #
  #   BashResult.run("docker build .")
  #
  #   CleanTestEnv.check(docker: true)
  #   # => Error: Docker images have leaked
  #
  # The common practice is to use this in rspec hooks
  #
  #   config.before(:suite) do
  #     Cutlass::CleanTestEnv.record
  #   end
  #
  #   config.after(:suite) do
  #     Cutlass::CleanTestEnv.check
  #   end
  class CleanTestEnv
    @before_images = []
    @skip_keys = ["HEROKU_API_KEY"]

    def self.skip_key(key)
      @skip_keys << key
    end

    def self.record
      @env_diff = EnvDiff.new(skip_keys: @skip_keys)
      @docker_diff = DockerDiff.new
    end

    def self.check(docker: ENV["CUTLASS_CHECK_DOCKER"])
      check_env
      check_images if docker
    end

    def self.check_env
      raise "Must call `record` first" if @env_diff.nil?
      return if @env_diff.same?

      raise <<~EOM
        Something mutated the environment on accident

        Diff:
        #{@env_diff}
      EOM
    end

    def self.check_images
      diff = @docker_diff.call
      return if diff.same?

      raise <<~EOM
        Docker images have leaked

        Your tests are generating docker images that were not cleaned up

        #{diff}

      EOM
    end
  end
end
