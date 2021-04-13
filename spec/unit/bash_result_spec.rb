# frozen_string_literal: true

module Cutlass
  RSpec.describe Cutlass::BashResult do
    it "preserves stdout, stderr, and status" do
      stdout = SecureRandom.hex(16)
      stderr = SecureRandom.hex(16)
      status = 0

      result = BashResult.new(
        stdout: stdout,
        stderr: stderr,
        status: status
      )

      expect(result.stdout).to eq(stdout)
      expect(result.stderr).to eq(stderr)
      expect(result.status).to eq(status)
    end

    it "success?" do
      result = BashResult.new(
        stdout: "",
        stderr: "",
        status: 0
      )
      expect(result.success?).to be_truthy

      result = BashResult.new(
        stdout: "",
        stderr: "",
        status: 1
      )

      expect(result.success?).to be_falsey
    end
  end
end
