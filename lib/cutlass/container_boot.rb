# frozen_string_literal: true

require_relative "container_control"

module Cutlass
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
end
