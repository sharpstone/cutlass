# frozen_string_literal: true

module Cutlass
  RSpec.describe Cutlass::App do
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

        expect(animals).to eq(["dog", "cat"])
      end
    end

    it "in_dir copies files from source dir to temp dir" do
      Dir.mktmpdir do |source_dir|
        FileUtils.touch(File.join(source_dir, "cat"))

        app = App.new(source_dir)
        app.in_dir do |tmpdir|
          expect(tmpdir.join("cat")).to exist

          expect(tmpdir).to_not eq(source_dir)
          expect(Dir.pwd).to_not eq(source_dir)
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
