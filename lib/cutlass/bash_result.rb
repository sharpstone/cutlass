module Cutlass
  # Value object containing the results of bash commands
  class BashResult
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
      @status = status
    end

    # @return [Boolean]
    def success?
      @status == 0
    end
  end
end
