# frozen_string_literal: true

require "csv_pipeline"

# Canonical customer-import pipeline with intentional rule ordering:
# 1. Normalize and validate required email fields
# 2. Apply optional defaults last so they do not mask required-field checks
module CustomerPipeline
  module_function

  def build
    CsvPipeline.build do |p|
      p.required :email do |f|
        f.transform CsvPipeline::NormalizeEmail
        f.validate  CsvPipeline::Presence
        f.validate  CsvPipeline::Format, pattern: CsvPipeline::EMAIL_PATTERN
      end

      p.optional :name, default: "empty"
    end
  end

  def process(source, **options)
    build.process(source, **options)
  end
end
