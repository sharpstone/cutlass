# Cutlass

Hack and slash your way to Cloud Native Buildpack (CNB) stability with cutlass! This library is similar in spirit to [heroku_hatchet](https://github.com/heroku/hatchet), but instead of building on Heroku infrastructure cutlass utilizes [pack](https://buildpacks.io/docs/tools/pack/) to locally build and verify buildpack behavior.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cutlass'
```

## Setup


It's assumed you've already got your project set up with rspec. If not see https://github.com/heroku/hatchet#hatchet-init, though using Hatchet is not required to use Cutlass.

You'll want to set up your app to run on CircleCI. Here's reference configs:

- [buildpacks-jvm](https://github.com/heroku/buildpacks-jvm/blob/main/.circleci/config.yml) note the versions of pack, the pack orb, and the executor. If you want to use the `start_container` interface your executor options are limited.


TODO: `cutlass init` command

## Initial Config

In your `spec_helper.rb` configure your default stack:

```ruby
# spec/spec_helper.rb

Cutlass.config do |config|
  config.default_builder = "heroku/buildpacks:18"

  # Where do your test fixtures live?
  config.default_repos_dir = [File.join(__dir__, "..", "repos", "ruby_apps")]

  # Where does your buildpack live?
  # Can be a directory or a Cutlass:LocalBuildpack instance
  config.default_buildpack_paths = [File.join(__dir__, "..")]
end
```


## Use

Initialize an instance with `Cutlass::App.new`

```ruby
Cutlass::App.new(
  "ruby-getting-started" # Directory name in your default repos dir
  config: { RAILS_ENV: "production" },
  builder: "heroku/buildpacks:18",
  buildpacks: ["heroku/nodejs-engine", File.join("..")],
  exception_on_failure: false
)
```

Once initialized call methods on the instance:

```ruby
Cutlass::App.new("ruby-getting-started").transaction do |app|
  # Safely modify files on disk before building the project
  Pathname(app.tmpdir).join("Procfile").write("web: rails s")


  # Build the app with `pack_build` using a block or regular method call
  app.pack_build do |result|
    expect(result.stdout).to include("SUCCESS")
  end

  # Build the app again with the non-block form of this method
  app.pack_build
  app.stdout # Grabs stdout from last build
  app.stderr # Grabs stdout from last build

  # Executes a `docker run` command in a background thread
  app.run_multi("ruby -v") do |result|
    expect(result.stdout).to match("2.7.2")
    expect(result.status).to eq(0)
  end

  # Binds the port 8080 inside of the container to a port on your host's localhost
  # so you can make network requests to the instance. This requires the app
  # to have an ENTRYPOINT in the docker file, such as an app with a `web` declaration
  # that also uses the `heroku/procfile` buildpack. The entrypoint must not exit
  # or the container will shut down.
  #
  # Another caveat to using this feature is that your "host" machine needs to be running on
  # a machine, not inside of a docker instance otherwise the networking will not bind correctly to the
  # child docker instance
  #
  # Basically there's a ton of caveats to using this feature. Tread lightly.
  app.start_container(expose_ports: [8080]) do |container|
    response = Excon.get("http://localhost:#{container.port(8080)}/", :idempotent => true, :retry_limit => 5, :retry_interval => 1)
    expect(response.body).to eq("Welcome to rails")

    # Warning, this does not use the CNB entrypoint so it's in a different dir
    # and doesn't have env vars set
    expect(container.bash_exec("pwd")).to eq("/workspace")
    expect(container.get_file_contents("/workspace/Gemfile.lock")).to_not include("BUNDLED WITH")
  end
end
```

## Initial Config (LocalBuildpack for package.toml)

If your needs a `package.toml` to function, then you can use Cutlass::LocalBuildpack. In your config:

```ruby
# spec/spec_helper.rb
MY_BUILDPACK = LocalBuildpack.new(directory: "/tmp/muh_buildpack_dir_with_packagetoml").call

Cutlass.config do |config|
  config.default_buildapacks = [MY_BUILDPACK]
end
```

Then you'll need to tear down the buildpack at the end of the test suite so the resulting docker image doesn't leak:

```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  config.after(:suite) do
    MY_BUIDLPACK.teardown
  end
end
```

In additon to the standard `package.toml` interface, if this directory has a `build.sh` file that file will be executed.

## API

### Cutlass::App Init options:

- @param repo_name [String] the path to a directory on disk, or the name of a directory inside of the `config.default_repos_dir`.
- @param builder [String] the name of a CNB "builder" used to build the app against. Defaults to `config.default_builder`.
- @param buildpacks [Array<String>] the array of buildpacks to build the app against. Defaults to `config.default_buildpack_paths`.
- @param config [Hash{Symbol => String}, Hash{String => String}] env vars to set against the app before it is built.
- @param exception_on_failure: [Boolean] when truthy failures on `app.pack_build` will result in an exception. Default is true.

### Cutlass::App object API

The app object acts as the main interface between your test suite and much of the behavior of cutlass. Here are the suggested methods:


- `app.transaction` Yields a block with itself. Copies over the example repo to a temporary path. When the block is finished executing, the path is cleaned up and the `teardown` callbacks are called on the application. If an image has been built using `pack_build` the end of the transaction will clean it up.
- `app.pack_build` Yields a block with a `Cutlass::BashResult`. Triggers a build via the `pack` CLI. It can be invoked multiple times inside of a transaction for testing cache behavior.
- `app.start_container` boots a container instance and connects it to a local port. Yields a `Cutlass::ContainerControl` instance with information about the container such as the port it is connected to.
- `app.run` Takes a string with a shell command and executes it in docker syncronously, returns a BashResult object. By default will raise an error if the status code returns non-zero. Can be disabled with kwarg `exception_on_failure: false`
- `app.run_multi` takes a string with a shell command and executes it async inside of docker. Yields a `Cutlass::BashResult` object. By default will raise an error if the status code returns non-zero. Can be disabled with kwarg `exception_on_failure: false`

These methods can also be used, but they're lower level and are not needed when using `app.transaction`:

- `app.in_dir` Yields a block with itself. Copies over example repo to a temporary path. When the block is finished executing the path is cleaned up.
- `app.teardown` Triggers any "teardown" callbacks, such as waiting on `run_mutli` blocks to complete. This is called automatically via `app.transaction`

### Cutlass::BashResult

An instance of BashResult is returned whenever Cutlass interacts with the shell or a shell-like object. For instance `app.pack_build` runs the `pack` command on the CLI and yelds a BashResult object with the results

- `result.stdout` Stdout from the command that was run
- `result.stderr` Stderr from the command that was run
- `result.status` Status code integer from the command that was run
- `result.success?` Truthy is status code was zero
- `result.fail?` Falsey if status code was zero

### Cutlass::ContainerControl

Once built an app can `app.start_container` to yield a ContainerControl object.

- `container.port(<port>)` Returns the port on the host machine (your computer, not docker) that docker is bound to
- Warning: These following commands do not use the CNB entry point so CNB env vars are not loaded and it my be a different dir than you're expecting
  - `container.bash_exec(<command>)` Executes a bash command inside of a running container. Returns a BashResult object. By default this will raise an exception if the command returns non-zero exit code. Use kwarg `container.bash_exec(<command>, exception_on_failure: false)` to disable. Returns a BashResult object.
  - `container.contains_file?(<file path>)` Checks to see if a given file exists on disk. Returns a BashResult object
  - `container.file_contents(<file path>)` Runs `cat` on a given file. Returns a BashResult object

## Test Help

### Clean ENV check

Make sure that environment variables do not leak from one test to another by configuring a check to run after your suite finishes:

```ruby
# spec/spec_helper.rb

RSpec.configure do |config|
  config.before(:suite) do
    Cutlass::CleanTestEnv.record
  end

  config.after(:suite) do
    Cutlass::CleanTestEnv.check
  end
end
```

### Clean ENV

If one of your tests does modify your local process memory and you can't change that, then you can wrap that code inside:

```ruby
Cutlass.in_fork do
  # Code here is executed in a fork
  # non-zero exit code will result in errors being re-raised
end
```

## Debugging

To get a firehose of info including the `pack` command used to build your app, you can set env vars `CUTLASS_DEBUG=1` or `DEBUG=1`.

## Ruby Protips:

- [Rspec basics](https://github.com/heroku/hatchet#basic-rspec)
- [Ruby basics](https://github.com/heroku/hatchet#basic-ruby)
- My favorite way to manipualate things on disk is through the [Pathname](https://docs.ruby-lang.org/en/3.0.0/Pathname.html) object which wraps many `File` and `FileUtils` commands.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

Be sensitive about test time. If a fixture needs a docker image, but not a CNB built image...use a simple dockerfile as a fixture as it's faster.

All tests locally that take more than a second are tagged with `slow: true`. The test suite is pretty snappy, but you can iterate faster by running tests tagged without slow first and then if they pass running the slow ones:

```
alias fast="bundle exec rspec --tag \~slow && bundle exec rspec --tag slow"
```

Tests on CI are runn with `parallel_split_test` which you can also use locally. All flags given to pst are passed to rspec.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/cutlass. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/cutlass/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Cutlass project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/cutlass/blob/main/CODE_OF_CONDUCT.md).
