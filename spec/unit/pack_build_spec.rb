# frozen_string_literal: true

module Cutlass
  RSpec.describe Cutlass::PackBuild do
    it "builds a docker image", slow: true do
      with_stub_buildpack do |buildpack|
        Dir.mktmpdir do |app_dir|
          app_dir = Pathname(app_dir)

          pack_build = Cutlass::PackBuild.new(
            app_dir: app_dir,
            builder: "heroku/buildpacks:18",
            buildpacks: buildpack
          )

          diff = DockerDiff.new

          pack_build.call

          expect(pack_build.stdout).to include("Successfully built image")

          expect(diff.call.changed?).to be_truthy
          expect(pack_build.success?).to be_truthy
        ensure
          pack_build&.teardown if pack_build
        end
      end
    end
  end
end
