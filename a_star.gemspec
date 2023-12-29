# frozen_string_literal: true

require_relative "lib/a_star/version"

Gem::Specification.new do |spec|
  spec.name = "a_star"
  spec.version = AStar::VERSION
  spec.authors = ["Gavin Stark"]
  spec.email = ["gavin@gstark.com"]

  spec.summary = "Implements the A* path finding algorithm."
  spec.homepage = "https://github.com/gstark/a_star"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/gstark/a_star"
  spec.metadata["changelog_uri"] = "https://github.com/gstark/a_star/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
