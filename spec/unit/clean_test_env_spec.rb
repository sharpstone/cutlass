# frozen_string_literal: true

module Cutlass
  RSpec.describe Cutlass::EnvDiff do
    it "detects changes in the environment" do
      diff = EnvDiff.new(before_env: {foo: "bar"}, env: {})

      expect(diff.changed?).to be_truthy
      expect(diff.to_s).to include("ENV['foo'] changed from 'bar' to ''")
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

    it "checks docker images", slow: true do
      Dir.mktmpdir do |dir|
        Cutlass.in_fork do
          image_name = "cutlass_#{SecureRandom.hex(10)}:sup"

          CleanTestEnv.record
          dir = Pathname(dir)
          dockerfile = dir.join("Dockerfile")
          dockerfile.write <<~EOM
            FROM heroku/heroku:18
            CMD ["echo", "Hello world #{image_name}!"]
          EOM

          run!("docker build -t #{image_name}  #{dir.join(".")} 2>&1")

          expect {
            CleanTestEnv.check(docker: true)
          }.to raise_error do |e|
            expect(e.message).to include("Docker images have leaked")
            expect(e.message).to include(image_name)
          end
        ensure
          # If we don't delete this env var, then the suite exit check fires
          # after this test, and we just mutated it's global state so it will likely
          # fail in a multi-process environment.
          ENV.delete("CUTLASS_CHECK_DOCKER")
          Docker::Image.get(image_name)&.remove(force: true) if image_name
        end
      end
    end
  end
end
