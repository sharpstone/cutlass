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
      stdout = @container.logs(stdout: 1)
      stderr = @container.logs(stderr: 1)
      yield ContainerControl.new(@container)
    rescue Docker::Error::ConflictError => e
      raise e, <<~EOM
        boot stdout: #{stdout}
        boot stderr: #{stderr}
      EOM
    ensure
      @container&.delete(force: true)
    end
  end

  RSpec.describe Cutlass::ContainerBoot do
    it " allows exec in a container and exposing container port", slow: true do
      Dir.mktmpdir do |dir|
        dir = Pathname(dir)

        image_name = Cutlass.default_image_name
        dockerfile = dir.join("Dockerfile")
        dockerfile.write <<~EOM
          FROM heroku/heroku:20

          # Entrypoint cannot exit or the container will not stay booted
          #
          # This command is an echo server with socat
          # link: https://gist.github.com/ramn/cfe0021b48c3e5d1f3f3#file-socat_http_echo_server-sh
          #
          ENTRYPOINT socat -v -T0.05 tcp-l:8080,reuseaddr,fork system:"echo 'HTTP/1.1 200 OK'; echo 'Connection: close'; echo; cat"
        EOM

        run!("docker build -t #{image_name} #{dir.join(".")} 2>&1")
        image = Docker::Image.get(image_name)

        ContainerBoot.new(image_id: image.id, expose_ports: [8080]).call do |container|
          expect(container.contains_file?("lol")).to be_falsey

          container.bash_exec("touch lol")
          expect(container.contains_file?("lol")).to be_truthy

          payload = SecureRandom.hex(10)
          response = Excon.post(
            "http://localhost:#{container.get_host_port(8080)}/?payload=#{payload}",
            idempotent: true,
            retry_limit: 5,
            retry_interval: 1
          )

          expect(response.body).to include("?payload=#{payload}")
          expect(response.status).to eq(200)
        end
      ensure
        image&.remove(force: true)
      end
    end
  end
end
