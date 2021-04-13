# frozen_string_literal: true

module Cutlass
  RSpec.describe Cutlass::App do
    it "completes teardown callbacks before erroring" do
      Dir.mktmpdir do |app_dir|
        stringio = StringIO.new
        expect {
          App.new(app_dir, warn_io: stringio).transaction do |app|
            app.on_teardown do
              raise "nopenopenope"
            end

            app.on_teardown do
              raise "houston we have a problem"
            end
          end
        }.to raise_error do |e|
          expect(e.message).to match("houston we have a problem")
        end

        expect(stringio.string).to include("houston we have a problem")
        expect(stringio.string).to include("nopenopenope")
      end
    end
    it "builds", slow: true do
      Dir.mktmpdir do |app_dir|
        run_multi_called_string = nil

        App.new(
          app_dir,
          builder: "heroku/buildpacks:18",
          buildpacks: ["heroku/ruby", "heroku/procfile"]
        ).transaction do |app|
          app.tmpdir.join("Gemfile").write(<<~EOM)
          EOM

          app.tmpdir.join("Gemfile.lock").write(<<~EOM)
            GEM
              specs:

            PLATFORMS
              ruby
              x86_64-darwin-19
              x86_64-linux

            DEPENDENCIES

            RUBY VERSION
               ruby 2.7.2p137
          EOM

          app.tmpdir.join("Procfile").write(<<~EOM)
            web: touch lol && tail -f lol # Need an entrypoint that doesn't exit
          EOM

          app.pack_build do |result|
            expect(result.stdout).to include("Successfully built image")
          end

          # App#stdout is the same as App#last_build.stdout
          expect(app.stdout).to include("Successfully built image")

          expect(app.run("pwd")).to match("/workspace")

          app.run_multi("pwd") do |result|
            run_multi_called_string = "called"
            expect(result).to match("/workspace")
          end

          app.start_container do |container|
            expect(container.bash_exec("ls /app")).to include("Gemfile")
          end
        end

        expect(run_multi_called_string).to eq("called")
      end
    end

    it "what happens in a transaction on disk stays in a transaction" do
      Dir.mktmpdir do |source_dir|
        App.new(source_dir).transaction do |app|
          FileUtils.touch("cat")

          expect(Pathname(Dir.pwd).join("cat")).to exist
        end

        expect(Pathname(source_dir)).to be_empty
        expect(Pathname(Dir.pwd).join("cat")).to_not exist
      end
    end

    it "transaction copies source dir" do
      Dir.mktmpdir do |source_dir|
        FileUtils.touch(File.join(source_dir, "cat"))

        App.new(source_dir).transaction do |app|
          expect(Pathname(Dir.pwd).join("cat")).to exist
        end
      end
    end

    it "transaction calls teardown blocks" do
      Dir.mktmpdir do |source_dir|
        animals = []
        App.new(source_dir).transaction do |app|
          app.on_teardown do
            animals << "dog"
          end

          app.on_teardown do
            animals << "cat"
          end

          expect(animals).to eq([])
        end

        expect(animals.sort).to eq(["cat", "dog"])
      end
    end

    it "in_dir copies files from source dir to temp dir" do
      Dir.mktmpdir do |source_dir|
        FileUtils.touch(File.join(source_dir, "cat"))

        App.new(source_dir).tap do |app|
          app.in_dir do |tmpdir|
            expect(tmpdir.join("cat")).to exist

            expect(tmpdir).to_not eq(source_dir)
            expect(Dir.pwd).to_not eq(source_dir)
          end
        end
      end
    end

    it "defaults" do
      Dir.mktmpdir do |source_dir|
        app = App.new(source_dir)

        expect(app.config).to eq({})
        expect(app.builder).to eq(Cutlass.default_builder)
        expect(app.buildpacks).to eq(Cutlass.default_buildpack_paths)
        expect(app.exception_on_failure).to eq(true)
      end
    end
  end
end
