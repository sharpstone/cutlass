module Cutlass
  class BashResult
    attr_reader :stdout, :stderr, :status

    def initialize(stdout: , stderr: , status:)
      @stdout = stdout
      @stderr = stderr
      @status = status
    end

    def success?
      @status == 0
    end
  end
end
