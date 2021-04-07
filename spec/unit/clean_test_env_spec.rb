# frozen_string_literal: true

module Cutlass
  RSpec.describe Cutlass::EnvDiff do
    it "detects changes in the environment" do
      diff = EnvDiff.new(before_env: {foo: "bar"}, env: {})

      expect(diff.changed?).to be_truthy
      expect("#{diff}").to include("ENV['foo'] changed from 'bar' to ''")
    end
  end

  RSpec.describe Cutlass::CleanTestEnv do
    it "checks environment modifications" do
      Cutlass.in_fork do
        CleanTestEnv.record
        # CleanTestEnv.check

        ENV[SecureRandom.hex(10).to_s] = "dog"

        expect {
          CleanTestEnv.check
        }.to raise_error(/Something mutated the environment/)
      end
    end

    it "checks docker images" do
      Dir.mktmpdir do |dir|
        image_name = "cutlass_#{SecureRandom.hex(10)}:sup"

        CleanTestEnv.record
        dir = Pathname(dir)
        dockerfile = dir.join("Dockerfile")
        dockerfile.write <<~EOM
          FROM alpine
          CMD ["echo", "Hello world #{image_name}!"]
        EOM

        run!("docker build -t #{image_name}  #{dir.join('.')} 2>&1")

        expect {
          CleanTestEnv.check(docker: true)
        }.to raise_error /Docker images have leaked/
      ensure
        repo_name, tag_name = image_name.split(":")

        docker_list = run!("docker images --no-trunc | grep #{repo_name} | grep #{tag_name}").strip
        run!("docker rmi #{image_name} --force") if !docker_list.empty?
      end
    end
  end
end
