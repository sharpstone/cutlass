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
end
