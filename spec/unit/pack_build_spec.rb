# frozen_string_literal: true

module Cutlass


  RSpec.describe Cutlass::PackBuild do
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
          file.dirname.mkpath;
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

        local_buildpack = LocalBuildpack.new(directory: dir)
        local_buildpack.call
        yield local_buildpack
      ensure
        local_buildpack.teardown if local_buildpack
      end
    end

    it "builds an docker image" do
      with_stub_buildpack do |buildpack|

        Dir.mktmpdir do |app_dir|
          app_dir = Pathname(app_dir)

          pack_build = Cutlass::PackBuild.new(
            app_dir: app_dir,
            builder: nil,
            buildpacks: buildpack
          )

          diff = DockerDiff.new

          pack_build.call

          expect(pack_build.stdout).to include("Successfully built image")

          expect(diff.call.changed?).to be_truthy
          expect(pack_build.success?).to be_truthy
        ensure
          pack_build.teardown if pack_build
        end
      end
    end
  end
end
