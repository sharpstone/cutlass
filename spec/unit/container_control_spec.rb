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
      bash_exec("[[ -f '#{path}' ]]").status == 0
    end

    def get_file_contents(path)
      bash_exec("cat '#{path}'").stdout
    end

    def bash_exec(cmd, exception_on_failure: true)
      stdout, stderr, status = @container.exec(["bash", "-c", cmd])
      result = BashExecResult.new(stdout: stdout, stderr: stderr, status: status)

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
      sleep 10

      puts `docker container list`
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
          buildpacks: "heroku/nodejs"
        ).transaction do |app|
          app.tmpdir.join("package.json").write("{}")
          app.pack_build do |result|

            ContainerBoot.new(image_id: image.id).call do |container|
              expect(container.contains_file?("lol")).to be_falsey

              container.bash_exec("touch lol")
              expect(container.contains_file?("lol")).to be_truthy
            end
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
    #       CMD ["echo", "Hello world #{image_name}!"]
    #     EOM

    #     run!("docker build -t #{image_name}  #{dir.join(".")} 2>&1")
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
  # end
end
