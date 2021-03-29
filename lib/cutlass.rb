# frozen_string_literal: true

require "tempfile"
require_relative "cutlass/version"

# Cutlass
module Cutlass
  # Error
  class Error < StandardError; end


  def self.config
    yield self
  end

  class << self
    # Cutlass.default_builder
    # Cutlass.default_buildpack_paths
    attr_accessor :default_builder, :default_buildpack_paths
  end


  def self.default_repo_dirs=(dirs)
    @default_repo_dirs = Array(dirs)
  end

  def self.default_repo_dirs
    @default_repo_dirs
  end

  def self.in_fork
    Tempfile.create("stdout") do |tmp_file|
      pid = fork do
        $stdout.reopen(tmp_file, "a")
        $stderr.reopen(tmp_file, "a")
        $stdout.sync = true
        $stderr.sync = true
        yield
        Kernel.exit!(0) # needed for https://github.com/seattlerb/minitest/pull/683
      end
      Process.waitpid(pid)

      if $?.success?
        print File.read(tmp_file)
      else
        raise File.read(tmp_file)
      end
    end
  end
end

require_relative "cutlass/bash_result"
