# frozen_string_literal: true

module Cutlass
  RSpec.describe Cutlass do
    it "is configurable" do
      Cutlass.in_fork do
        Cutlass.config do |config|
          config.default_builder = "foo/bar"
          config.default_repo_dirs = ["foo"]
          config.default_buildpack_paths = ["bar"]
        end

        expect(Cutlass.default_builder).to eq("foo/bar")
        expect(Cutlass.default_repo_dirs).to eq(["foo"])
        expect(Cutlass.default_buildpack_paths).to eq(["bar"])
      end
    end
  end
end
