# frozen_string_literal: true

module Cutlass
  class PackBuild
    private; attr_reader :app_dir, :config, :builder, :image_name, :buildpacks; :env_arguments; public

    def initialize(app_dir:, image_name: default_image_name, buildpacks: [], config: {}, builder: )
      @app_dir = app_dir
      @builder = builder
      @image_name = image_name
      @env_arguments = config.map {|key, value| "--env #{key}=#{value}" }.join(" ")

      @buildpacks = buildpacks.map do |buildpack|
        if buildpack.respond_to?(:name)
          buildpack.name
        else
          buildpack
        end
      end
    end

    def call
      puts pack_command if ENV["CUTLASS_DEBUG"] || ENV["DEBUG"]
      call_pack
    end

    private def call_pack
      stdout, stderr, status = Open3.capture3(pack_command)

      if pack_status == 0
        image = Docker::Image.get(image_name)
      else
        image = nil
        if exception_on_failure
          raise "Pack exited with status code #{pack_status}, indicating an error and failed build!\nstdout: #{pack_stdout}\nstderr: #{pack_stderr}"
        end
      end
    end

    def pack_command
      "pack build #{image_name} --path #{app_dir} -B #{builder} --buildpack #{buildpacks.join(',')} #{env_arguments}"
    end

    def default_image_name
      "cutlass_image_#{SecureRandom.hex(10)}"
    end
  end

  RSpec.describe Cutlass::LocalBuildpack do
    it "calls build.sh" do
      Dir.mktmpdir do |dir|
        name = SecureRandom.hex(10)
        dir = Pathname(dir)
        dir.join("package.toml").write(<<~EOM)
          [buildpack]
          uri = "."
        EOM
        dir.join("buildpack.toml").write(<<~EOM)
          [buildpack]
          id = "cutlass/supreme_#{name}"
          version = "0.0.1"

          [[stacks]]
          id = "io.buildpacks.stacks.bionic"
        EOM

        dir.join("build.sh").tap do |script|
          script.write(<<~EOM)
            touch #{name}
          EOM

          FileUtils.chmod("+x", script)
        end

        local_buildpack = LocalBuildpack.new(directory: dir)
        local_buildpack.call

        expect(dir.entries.map(&:to_s)).to include(name)
      ensure
        local_buildpack.teardown if local_buildpack
      end
    end

    it "builds images and tears them down" do
      Dir.mktmpdir do |dir|
        name = SecureRandom.hex(10)
        dir = Pathname(dir)
        dir.join("package.toml").write(<<~EOM)
          [buildpack]
          uri = "."
        EOM
        dir.join("buildpack.toml").write(<<~EOM)
          [buildpack]
          id = "cutlass/supreme_#{name}"
          version = "0.0.1"

          [[stacks]]
          id = "io.buildpacks.stacks.bionic"
        EOM

        diff = DockerDiff.new
        local_buildpack = LocalBuildpack.new(directory: dir)
        local_buildpack.call
        expect(diff.call.changed?).to be_truthy
        local_buildpack.teardown if local_buildpack

        expect(diff.call.changed?).to be_falsey
      end
    end
  end
end

