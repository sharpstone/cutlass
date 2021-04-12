# frozen_string_literal: true

module Cutlass
  # Converts a buildpack in a local directory into an image that pack can use natively
  #
  #   MY_BUILDPACK = LocalBuildpack.new(directory: "/tmp/muh_buildpack").call
  #   puts MY_BUILDPACK.name #=> "docker:://cutlass_local_buildpack_abcd123"
  #
  #   Cutlass.config do |config|
  #     config.default_buildapacks = [MY_BUILDPACK]
  #   end
  #
  # Note: Make sure that any built images are torn down in in your test suite
  #
  #    config.after(:suite) do
  #      MY_BUILDPACK.teardown
  #
  #      Cutlass::CleanTestEnv.check
  #    end
  #
  class LocalBuildpack
    private

    attr_reader :image_name

    public

    def initialize(directory:)
      @built = false
      @directory = Pathname(directory)
      @image_name = "cutlass_local_buildpack_#{SecureRandom.hex(10)}"
    end

    def teardown
      return unless built?

      image = Docker::Image.get(image_name)
      image.remove(force: true)
    end

    def name
      call
      "docker://#{image_name}"
    end

    def call
      return if built?
      raise "must be directory: #{@directory}" unless @directory.directory?

      @built = true

      call_build_sh
      call_pack_buildpack_package

      self
    end

    private def call_pack_buildpack_package
      raise "must contain package.toml: #{@directory}" unless @directory.join("package.toml").exist?

      pack_command = "pack buildpack package #{image_name} --config #{@directory.join("package.toml")} --format=image"
      result = BashResult.run(pack_command)

      return if result.success?
      raise <<~EOM
        While packaging meta-buildpack: pack exited with status code #{result.status},
        indicating an error and failed build!

        stdout: #{result.stdout}
        stderr: #{result.stderr}
      EOM
    end

    private def call_build_sh
      build_sh = @directory.join("build.sh")
      return unless build_sh.exist?

      result = BashResult.run("cd #{@directory} && bash #{build_sh}")

      return if result.success?

      raise <<~EOM
        Buildpack build step failed!

        stdout: #{result.stdout}
        stderr: #{result.stderr}
      EOM
    end

    def built?
      @built
    end
  end
end
