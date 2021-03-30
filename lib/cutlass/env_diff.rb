# frozen_string_literal: true

module Cutlass
  class EnvDiff
    attr_reader :before_env, :env, :skip_keys

    def initialize(before_env: ENV.to_h.dup, skip_keys: [], env: ENV)
      @env = env
      @before_env = before_env.freeze
      @skip_keys = skip_keys
    end

    def to_s
      env_keys.map do |k|
        next if @env[k] == @before_env[k]

        "  ENV['#{k}'] changed from '#{@before_env[k]}' to '#{@env[k]}'"
      end.compact.join($/)
    end

    def same?
      !changed?
    end

    def changed?
      env_keys.detect do |k|
        @env[k] != @before_env[k]
      end
    end

    def env_keys
      keys = (@before_env.keys + @env.keys) - skip_keys
      keys.uniq
    end
  end
end
