# frozen_string_literal: true

module Cutlass
  class PackBuild
    private; attr_reader :app_dir, :config, :builder, :image_name, :buildpacks, :exception_on_failure, :env_arguments; public

    def initialize(app_dir:, exception_on_failure: true, image_name: default_image_name, buildpacks: [], config: {}, builder: nil)

      @app_dir = app_dir
      @builder = builder
      @image_name = image_name
      @env_arguments = config.map {|key, value| "--env #{key}=#{value}" }.join(" ")
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
      puts pack_command if ENV["CUTLASS_DEBUG"] || ENV["DEBUG"]
      call_pack
    end

    def failed?
      !success?
    end

    def success?
      result.success?
    end

    private def call_pack
      stdout, stderr, status = Open3.capture3(pack_command)
      @result = BashResult.new(stdout: stdout, stderr: stderr, status: status)

      if status == 0
        @image = Docker::Image.get(image_name)
      else
        @image = nil

        if exception_on_failure
          raise <<~EOM
            Pack exited with status code #{status}, indicating a build failed

            command: #{pack_command}
            stdout: #{stdout}
            stderr: #{stderr}
          EOM
        end
      end
    end

    def builder_arg
      "-B #{builder}" if builder
    end

    def pack_command
      "pack build #{image_name} --path #{app_dir} #{builder_arg} --buildpack #{buildpacks.join(',')} #{env_arguments}"
    end

    def default_image_name
      "cutlass_image_#{SecureRandom.hex(10)}"
    end
  end
end
