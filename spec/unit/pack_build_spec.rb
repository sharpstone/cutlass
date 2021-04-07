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

  RSpec.describe Cutlass::PackBuild do
    it "" do
      build = PackBuild.new(app_dir: "foo", builder: "bar")
      expect(build.default_image_name).to_not be_empty
    end
  end
end
