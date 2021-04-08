# frozen_string_literal: true

module Cutlass
  class ContainerControl
    def initialize(container)
      @container
    end

    def get_host_port(port)
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

      expose_ports.each do |port|
        config["ExposedPorts"]["#{port}/tcp"] = {}

        # If we do not specify a port, Docker will grab a random unused one:
        port_bindings["#{port}/tcp"] = [{"HostPort" => ""}]
      end

      @container = Docker::Container.create(config)
    end

    def call
      @container.start
      yield ContainerContainer.new(@container)
    ensure
      @container&.delete(force: true)
    end
  end

  RSpec.describe Cutlass::App do
    it "builds", slow: true do
    end
  end
end
