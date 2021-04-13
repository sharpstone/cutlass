# frozen_string_literal: true

module Cutlass
  # Build an image with `pack` and cloud native buildpacks
  #
  #  begin
  #    build = PackBuild.new(app_dir: dir, buildpacks: ["heroku/ruby"], builder: "heroku/buildpacks:18")
  #    build.call
  #
  #    build.stdout # => "...Successfully built image"
  #    build.success? # => true
  #  ensure
  #    build.teardown
  #  end
  #
  class PackBuild
    private

    attr_reader :app_dir, :config, :builder, :image_name, :buildpacks, :exception_on_failure, :env_arguments

    public

    def initialize(
      app_dir:,
      config: {},
      builder: nil,
      buildpacks: [],
      image_name: Cutlass.default_image_name,
      exception_on_failure: true
    )
      @app_dir = app_dir
      @builder = builder
      @image_name = image_name
      @env_arguments = config.map { |key, value| "--env #{key}=#{value}" }.join(" ")
      @exception_on_failure = exception_on_failure
      @image = nil
      @result = nil

      @buildpacks = Array(buildpacks).map do |buildpack|
        if buildpack.respond_to?(:name)
          buildpack.name
        else
          buildpack
        end
      end
    end

    def image_id
      raise "No image ID, container was not successfully built, #{error_message}" if @image.nil?
      @image.id
    end

    def result
      raise "Must execute method `call` first" unless @result

      @result
    end

    def teardown
      @image&.remove(force: true)
    end

    def stdout
      result.stdout
    end

    def stderr
      result.stderr
    end

    def call
      puts pack_command if Cutlass.debug?
      call_pack

      puts @result.stdout if Cutlass.debug?
      puts @result.stderr if Cutlass.debug?
      self
    end

    def failed?
      !success?
    end

    def success?
      result.success?
    end

    private def call_pack
      @result = BashResult.run(pack_command)

      if @result.success?
        @image = Docker::Image.get(image_name)
      else
        @image = nil

        raise error_message if exception_on_failure
      end
    end

    private def error_message
      <<~EOM
        Pack exited with status code #{@result.status}, indicating a build failed

        command: #{pack_command}
        stdout: #{stdout}
        stderr: #{stderr}
      EOM
    end

    def builder_arg
      "-B #{builder}" if builder
    end

    def pack_command
      "pack build #{image_name} --path #{app_dir} #{builder_arg} --buildpack #{buildpacks.join(",")} #{env_arguments} #{"-v" if Cutlass.debug?}"
    end
  end
end
