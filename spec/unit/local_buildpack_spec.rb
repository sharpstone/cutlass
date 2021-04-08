# frozen_string_literal: true

module Cutlass
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

