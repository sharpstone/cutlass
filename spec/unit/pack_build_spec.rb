# frozen_string_literal: true

module Cutlass
  class PackBuild
    private; attr_reader :app_dir, :config, :builder, :image_name, :buildpacks; public

    def initialize(app_dir:, image_name: default_image_name, buildpacks: [], config: {}, builder: )
      @config = config
      @app_dir = app_dir
      @builder = builder
      @image_name = image_name
      @buildpacks = buildpacks
    end

    def call
    end

    def default_image_name
      "cutlass_image_#{SecureRandom.hex(10)}"
    end
  end

  class PackageLocalBuildpack
    private; attr_reader :image_name; public

    def initialize(directory)
      @built = false
      @directory = Pathname(directory)
      @image_name = "cutlass_local_buildpack_#{SecureRandom.hex(10)}"
    end

    def name
      call
      "docker:://#{image_name}"
    end

    def call
      return if built?
      raise "must be directory: #{@directory}" unless @directory.directory?
      raise "must contain package.toml: #{@directory}" unless @directory.join("package.toml").exist?

      @built = true
      stdout, stderr, status = Open3.capture3(pack_command)
      if status != 0
        raise "While packaging meta-buildpack: pack exited with status code #{status}, indicating an error and failed build!\nstderr: #{pack_stderr}"
      end
    end

    private def built?
      @built
    end

    private def pack_command
      "pack buildpack package #{image_name} --config #{@directory.join("package.toml")}"
    end
  end

  RSpec.describe Cutlass::PackBuild do
  end

  RSpec.describe Cutlass::PackBuild do
    it "" do
      build = PackBuild.new(app_dir: "foo", builder: "bar")
      expect(build.default_image_name).to_not be_empty
    end
  end
end
