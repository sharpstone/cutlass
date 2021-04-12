# frozen_string_literal: true

require_relative "container_control"

module Cutlass
  # Boots containers and tears 'em down
  #
  # Has a single method ContainerBoot#call which returns an instance of
  #
  #   boot = ContainerBoot.new(image_id: @image.id)
  #   boot.call do |container_control|
  #     container_control.class # => ContainerControl
  #     container_control.bash_exec("pwd")
  #   end
  #
  # The number one reason to boot a container is to be able to exercise a booted server from
  # within the container. To do this you need to tell docker want port to expose
  # inside of the container. Docker will expose that port and bind it to a free port
  # on the "host" i.e. your local machine. From there you can make queries to various
  # docker ports:
  #
  #   boot = ContainerBoot.new(image_id: @image.id, expose_ports: [8080])
  #   boot.call do |container_control|
  #     local_port = container_control.get_host_port(8080)
  #
  #     `curl localhost:#{local_port}`
  #   end
  #
  # Note: Booting a container only works if the image has an ENTRYPOINT that does
  # not exit.
  #
  # Note: Running `bash_exec` commands from this context gives you a raw access to the
  # container. It does not execute the container's entrypoint. That means if you're running
  # inside of a CNB image, that env vars won't be set and the directory might be different.
  class ContainerBoot
    def initialize(image_id:, expose_ports: [])
      @expose_ports = Array(expose_ports)
      config = {
        "Image" => image_id,
        "ExposedPorts" => {},
        "HostConfig" => {
          "PortBindings" => {}
        }
      }

      port_bindings = config["HostConfig"]["PortBindings"]

      @expose_ports.each do |port|
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
      yield ContainerControl.new(@container, ports: @expose_ports)
    rescue => error
      raise error, <<~EOM
        message #{error.message}

        boot stdout: #{stdout}
        boot stderr: #{stderr}
      EOM
    ensure
      @container&.delete(force: true)
    end
  end
end
