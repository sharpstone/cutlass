# frozen_string_literal: true

module Cutlass
  # This class is exposed via a ContainerBoot instance
  #
  # Once a container is booted, if a port is bound an instance will
  # return the local port that can be used to send network requests to the container.
  #
  # In addition bash commands can be executed via ContainerControl#bash_exec
  #
  class ContainerControl
    def initialize(container, ports: [])
      @container = container
      @ports = ports
    end

    def get_host_port(port)
      raise "Port not bound inside container: #{port}, bound ports: #{@ports.inspect}" unless @ports.include?(port)
      @container.json["NetworkSettings"]["Ports"]["#{port}/tcp"][0]["HostPort"]
    end

    def contains_file?(path)
      bash_exec("[[ -f '#{path}' ]]", exception_on_failure: false).status == 0
    end

    def get_file_contents(path)
      bash_exec("cat '#{path}'").stdout
    end

    def bash_exec(cmd, exception_on_failure: true)
      stdout_ish, stderr, status = @container.exec(["bash", "-c", cmd])

      result = BashResult.new(stdout: stdout_ish.first, stderr: stderr, status: status)

      return result if result.success?
      return result unless exception_on_failure

      raise <<~EOM
        bash_exec(#{cmd}) failed

        stdout: #{stdout}
        stderr: #{stderr}
      EOM
    end
  end
end
