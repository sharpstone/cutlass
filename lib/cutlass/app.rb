# frozen_string_literal: true

module Cutlass
  # Top level class for interacting with a "pack" app
  #
  #   Cutlass::App.new(
  #     path_to_rails_app,
  #     buildpacks: "heroku/ruby",
  #     builder: "heroku/buildpacks:18"
  #   ).transaction do |app|
  #     app.pack_build
  #
  #     expect(result.stdout).to include("Successfully built image")
  #   end
  class App
    attr_reader :builds, :config, :builder, :buildpacks, :exception_on_failure, :image_name, :tmpdir

    def initialize(
      source_path_name,
      config: {},
      warn_io: STDERR,
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
      @warn_io = warn_io
      @builder = builder
      @image_name = image_name
      @buildpacks = buildpacks
      @source_path_name = source_path_name
      @exception_on_failure = exception_on_failure
    end

    def stdout
      last_build.stdout
    end

    def stderr
      last_build.stderr
    end

    def success?
      last_build.success?
    end

    def fail?
      last_build.fail?
    end

    def last_build
      raise "You must `pack_build` first" if builds.empty?

      builds.last
    end

    def run(command, exception_on_failure: true)
      command = docker_command(command)
      result = BashResult.run(command)

      raise(<<~EOM) if result.failed? && exception_on_failure
        Command "#{command}" failed

        stdout: #{result.stdout}
        stderr: #{result.stderr}
        status: #{result.status}
      EOM

      result
    end

    private def docker_command(command)
      "docker run --entrypoint='/cnb/lifecycle/launcher' #{image_name} #{command.to_s.shellescape}"
    end

    def run_multi(command, exception_on_failure: true)
      raise "No block given" unless block_given?

      thread = Thread.new do
        yield run(command, exception_on_failure: exception_on_failure)
      end

      on_teardown { thread.join }
    end

    def start_container(expose_ports: [])
      raise "No block given" unless block_given?

      ContainerBoot.new(image_id: last_build.image_id, expose_ports: expose_ports).call do |container|
        yield container
      end
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
      errors = []
      @on_teardown.reverse.each do |callback|
        # Attempt to run all teardown callbacks
        begin
          callback.call
        rescue => e
          errors << e

          @warn_io.puts <<~EOM

            Error in teardown #{callback.inspect}

            It will be raised after all teardown blocks have completed

            #{e.message}

            #{e.backtrace.join($/)}
          EOM
        end
      end
    ensure
      errors.each do |e|
        raise e
      end
    end

    def on_teardown(&block)
      @on_teardown << block
    end

    private def source_path
      @source_path ||= Cutlass.resolve_path(@source_path_name)
    end
  end
end
