# frozen_string_literal: true

module Cutlass
  class App
    attr_reader :builds, :config, :builder, :buildpacks, :exception_on_failure, :image_name, :tmpdir

    def initialize(
      source_path_name,
      config: {},
      builder: Cutlass.default_builder,
      image_name: Cutlass.default_image_name,
      buildpacks: Cutlass.default_buildpack_paths,
      exception_on_failure: true
    )
      @tmpdir = nil
      @source_path = nil

      @builds = []
      @on_teardown = []

      @config = config
      @builder = builder
      @image_name = image_name
      @buildpacks = buildpacks
      @source_path_name = source_path_name
      @exception_on_failure = exception_on_failure
    end

    def stdout
      builds.last.stdout
    end

    def stderr
      builds.last.stderr
    end

    def success?
      builds.last.success?
    end

    def fail?
      builds.last.fail?
    end

    def pack_build
      build = PackBuild.new(
        config: config,
        app_dir: @tmpdir,
        builder: builder,
        buildpacks: buildpacks,
        image_name: image_name,
        exception_on_failure: exception_on_failure
      )
      on_teardown { build.teardown }

      @builds << build
      yield build.call
    end

    def transaction
      in_dir do
        yield self
      ensure
        teardown
      end
    end

    def in_dir
      Dir.mktmpdir do |dir|
        @tmpdir = Pathname(dir)

        FileUtils.copy_entry(source_path, @tmpdir)

        Dir.chdir(@tmpdir) do
          yield @tmpdir
        end
      end
    end

    def teardown
      @on_teardown.map(&:call)
    end

    def on_teardown(&block)
      @on_teardown << block
    end

    private def source_path
      @source_path ||= Cutlass.resolve_path(@source_path_name)
    end
  end
end
