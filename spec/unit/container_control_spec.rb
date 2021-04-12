# frozen_string_literal: true

module Cutlass
  RSpec.describe Cutlass::ContainerBoot do
    it " allows exec in a container and exposing container port", slow: true do
      Dir.mktmpdir do |dir|
        dir = Pathname(dir)

        image_name = Cutlass.default_image_name
        dockerfile = dir.join("Dockerfile")
        dockerfile.write <<~EOM
          FROM heroku/heroku:18

          # Entrypoint cannot exit or the container will not stay booted
          #
          # This command is an echo server with socat
          # link: https://gist.github.com/ramn/cfe0021b48c3e5d1f3f3#file-socat_http_echo_server-sh
          #
          ENTRYPOINT socat -v -T0.05 tcp-l:8080,reuseaddr,fork system:"echo 'HTTP/1.1 200 OK'; echo 'Connection: close'; echo; cat"
        EOM

        docker_build_out = run!("docker build -t #{image_name} #{dir.join(".")} 2>&1")
        image = Docker::Image.get(image_name)

        ContainerBoot.new(image_id: image.id, expose_ports: [8080]).call do |container|
          expect(container.contains_file?("lol")).to be_falsey

          container.bash_exec("touch lol")
          expect(container.contains_file?("lol")).to be_truthy

          payload = SecureRandom.hex(10)
          port = container.get_host_port(8080)

          response = Excon.post(
            "http://localhost:#{port}/?payload=#{payload}",
            idempotent: true,
            retry_limit: 5,
            retry_interval: 1
          )

          expect(response.body).to include("?payload=#{payload}")
          expect(response.status).to eq(200)
        end
      rescue => error
        raise error, <<~EOM
          #{error.message}

          docker build: #{docker_build_out}
        EOM
      ensure
        image&.remove(force: true)
      end
    end
  end
end
