require "open3"

module Cutlass
  # Value object containing the results of bash commands
  #
  # result = BashResult.run("echo 'lol')
  # result.stdout # => "lol"
  # result.status # => 0
  # result.success? # => true
  class BashResult
    def self.run(command)
      stdout, stderr, status = Open3.capture3(command)
      BashResult.new(stdout: stdout, stderr: stderr, status: status)
    end

    # @return [String]
    attr_reader :stdout

    # @return [String]
    attr_reader :stderr

    # @return [Numeric]
    attr_reader :status

    # @param stdout [String]
    # @param stderr [String]
    # @param status [Numeric]
    def initialize(stdout:, stderr:, status:)
      @stdout = stdout
      @stderr = stderr
      @status = status.to_i
    end

    # @return [Boolean]
    def success?
      @status == 0
    end

    def failed?
      !success?
    end

    # Testing helper methods
    def include?(value)
      stdout.include?(value)
    end

    def match?(value)
      stdout.match?(value)
    end

    def match(value)
      stdout.match(value)
    end
  end
end
