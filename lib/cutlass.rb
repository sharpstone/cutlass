# frozen_string_literal: true

require "tempfile"
require "fileutils"
require "pathname"

require "docker" # docker-api gem

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

  @default_buildpack_paths = []
  @default_repo_dirs = []
  def self.default_repo_dirs=(dirs)
    @default_repo_dirs = Array(dirs).map { |dir| Pathname(dir) }
  end

  def self.default_repo_dirs
    @default_repo_dirs
  end

  # Given a full path that exists it will return the same path.
  # Given the name of a directory within the default repo dirs,
  # it will match and return a full path
  def self.resolve_path(path)
    return Pathname(path) if Dir.exist?(path)

    children = @default_repo_dirs.map(&:children).flatten
    resolved = children.detect { |p| p.basename.to_s == path }

    return resolved if resolved

    raise(<<~EOM)
      No such directory name: #{path.inspect}

      #{children.map(&:basename).join($/)}
    EOM
  end

  def self.default_image_name
    "cutlass_image_#{SecureRandom.hex(10)}"
  end

  # Runs the block in a process fork to isolate memory
  # or environment changes such as ENV var modifications
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
require_relative "cutlass/app"
require_relative "cutlass/clean_test_env"

require_relative "cutlass/local_buildpack"
require_relative "cutlass/pack_build"
require_relative "cutlass/container_boot"
