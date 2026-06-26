# frozen_string_literal: true

require_relative "lib/csv_pipeline/version"

Gem::Specification.new do |spec|
  spec.name = "csv_pipeline"
  spec.version = CsvPipeline::VERSION
  spec.authors = ["Consultport Case Study"]
  spec.email = ["tech-case-study@consultport.com"]

  spec.summary = "Process CSV records through a configurable pipeline of transform and validation rules"
  spec.description = "A Ruby library that applies composable rules to CSV rows and collects all validation errors."
  spec.homepage = "https://github.com/YOUR_GITHUB_USERNAME/csv_pipeline"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"
  spec.add_runtime_dependency "csv", ">= 3.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage
  }

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject { |f| f.start_with?("spec/") }
  rescue StandardError
    Dir["{lib,examples}/**/*", "*.{md,gemspec,rake,LICENSE}"] + ["lib/csv_pipeline.rb"]
  end

  spec.require_paths = ["lib"]
  spec.metadata["rubygems_migrated_version"] = "3.0"
end
