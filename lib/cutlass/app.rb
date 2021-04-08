# frozen_string_literal: true

module Cutlass
  class App
    attr_reader :config, :builder, :buildpacks, :exception_on_failure
    def initialize(
      source_path_name,
      config: {},
      builder: Cutlass.default_builder,
      buildpacks: Cutlass.default_buildpack_paths,
      exception_on_failure: true
    )
      @on_teardown = []
      @source_path = nil
      @config = config
      @builder = builder
      @buildpacks = buildpacks
      @source_path_name = source_path_name
      @exception_on_failure = exception_on_failure
    end

    def pack_build
      # TODO
      yield result
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
        dir = Pathname(dir)

        FileUtils.copy_entry(source_path, dir)

        Dir.chdir(dir) do
          yield dir
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
