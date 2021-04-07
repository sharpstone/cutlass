# frozen_string_literal: true

require_relative "env_diff"

module Cutlass
  class CleanTestEnv
    @before_images = []
    @skip_keys = ["HEROKU_API_KEY"]

    def self.skip_key(key)
      @skip_keys << key
    end

    def self.record
      @env_diff = EnvDiff.new(skip_keys: @skip_keys)
      @before_image_ids = Docker::Image.all.map(&:id).sort.freeze
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
      now_images_hash = Docker::Image.all.each_with_object({}) {|image, hash| hash[image.id] = image }
      id_diff_array = now_images_hash.keys.sort - @before_image_ids

      return if id_diff_array.empty?

      leaked_images_diff = id_diff_array.map {|id| now_images_hash[id] }.each do |image|
        "  id: #{image.id}"
      end.join($/)

      raise <<~EOM
        Docker images have leaked

        Your tests are generating docker images that were not cleaned up

        #{leaked_images_diff}

      EOM
    end
  end
end
