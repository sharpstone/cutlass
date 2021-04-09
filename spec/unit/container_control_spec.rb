# frozen_string_literal: true

module Cutlass
  class ContainerControl
    def initialize(container)
      @container = container
    end

    def get_host_port(port)
      @container.json["NetworkSettings"]["Ports"]["#{port}/tcp"][0]["HostPort"]
    end

    def contains_file?(path)
      bash_exec("[[ -f '#{path}' ]]", exception_on_failure: false).status == 0
    end

    def get_file_contents(path)
      bash_exec("cat '#{path}'").stdout
    end

    def bash_exec(cmd, exception_on_failure: true)
      stdout_ish, stderr, status_ish = @container.exec(["bash", "-c", cmd])
      stdout = stdout_ish.first
      `exit #{status_ish}`
      status = $?

      result = BashResult.new(stdout: stdout, stderr: stderr, status: status)

      return result if status.success?
      return result unless exception_on_failure

      raise <<~EOM
        bash_exec(#{cmd}) failed

        stdout: #{stdout}
        stderr: #{stderr}
      EOM
    end
  end

  class ContainerBoot
    def initialize(image_id:, expose_ports: [])
      config = {
        "Image" => image_id,
        "ExposedPorts" => {},
        "HostConfig" => {
          "PortBindings" => {}
        }
      }

      port_bindings = config["HostConfig"]["PortBindings"]

      Array(expose_ports).each do |port|
        config["ExposedPorts"]["#{port}/tcp"] = {}

        # If we do not specify a port, Docker will grab a random unused one:
        port_bindings["#{port}/tcp"] = [{"HostPort" => ""}]
      end

      @container = Docker::Container.create(config)
    end

    def call
      raise "Must call with a block" unless block_given?

      @container.start!
      # puts @container.logs(stdout: 1, stderr: 1)
      yield ContainerControl.new(@container)
    ensure
      @container&.delete(force: true)
    end
  end

  RSpec.describe Cutlass::ContainerBoot do
    it "builds", slow: true do
      Dir.mktmpdir do |dir|
        App.new(
          dir,
          builder: default_heroku_builder,
          buildpacks: ["heroku/ruby", "heroku/procfile"]
        ).transaction do |app|
          app.tmpdir.join("Gemfile").write(<<~EOM)
          EOM

          app.tmpdir.join("Gemfile.lock").write(<<~EOM)
            GEM
              specs:

            PLATFORMS
              ruby
              x86_64-darwin-19
              x86_64-linux

            DEPENDENCIES

            RUBY VERSION
               ruby 2.7.2p137
          EOM

          app.tmpdir.join("Procfile").write(<<~EOM)
            web: touch foo && tail -f foo
          EOM

          app.pack_build do |result|
            # puts result.stdout
            # puts result.stderr

            image = Docker::Image.get(app.image_name)
            ContainerBoot.new(image_id: image.id).call do |container|
              expect(container.contains_file?("lol")).to be_falsey

              expect(container.bash_exec("ls /app").stdout).to include("Gemfile")
            end
          end
        end
      end
    end

    # it "builds", slow: true do
    #   Dir.mktmpdir do |dir|
    #     dir = Pathname(dir)

    #     image_name = Cutlass.default_image_name
    #     dockerfile = dir.join("Dockerfile")
    #     dockerfile.write <<~EOM
    #       FROM alpine

    #     EOM

    #     puts run!("docker build -t #{image_name} #{dir.join(".")} 2>&1")
    #     image = Docker::Image.get(image_name)

    #     ContainerBoot.new(image_id: image.id).call do |container|
    #       expect(container.contains_file?("lol")).to be_falsey

    #       container.bash_exec("touch lol")
    #       expect(container.contains_file?("lol")).to be_truthy
    #     end
    #   ensure
    #     image&.remove(force: true)
    #   end
    # end
  end
end
