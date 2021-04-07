# frozen_string_literal: true

module Cutlass

  # Converts a buildpack in a local directory into an image that pack can use natively
  #
  #   buildpack = LocalBuildpack.new(directory: "/tmp/muh_buildpack").call
  #   puts buildpack.name #=> "docker:://cutlass_local_buildpack_abcd123"
  #
  class LocalBuildpack
    private; attr_reader :image_name; public

    def initialize(directory: )
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
      stdout, stderr, status = Open3.capture3(pack_command)
      if status != 0
        raise "While packaging meta-buildpack: pack exited with status code #{status}, indicating an error and failed build!\nstderr: #{stderr}"
      end
    end

    private def call_build_sh
      build_sh = @directory.join("build.sh")
      return unless  build_sh.exist?

      stdout, stderr, status = Open3.capture3("cd #{@directory} && bash #{build_sh}")

      if status != 0
        raise "Buildpack build step failed!\nstdout: #{stdout}\nstderr: #{stderr}"
      end
    end

    def built?
      @built
    end
  end
end

