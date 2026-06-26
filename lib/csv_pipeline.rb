# frozen_string_literal: true

require_relative "csv_pipeline/version"
require_relative "csv_pipeline/exceptions"
require_relative "csv_pipeline/blank_policy"
require_relative "csv_pipeline/blank"
require_relative "csv_pipeline/messages"
require_relative "csv_pipeline/patterns"
require_relative "csv_pipeline/rule_invoker"
require_relative "csv_pipeline/header_validator"
require_relative "csv_pipeline/validation_error"
require_relative "csv_pipeline/record"
require_relative "csv_pipeline/rule"
require_relative "csv_pipeline/rules/conditional"
require_relative "csv_pipeline/rules"
require_relative "csv_pipeline/conditional_builder"
require_relative "csv_pipeline/schema"
require_relative "csv_pipeline/yaml_loader"
require_relative "csv_pipeline/exporters"
require_relative "csv_pipeline/csv_reader"
require_relative "csv_pipeline/field_builder"
require_relative "csv_pipeline/pipeline"
require_relative "csv_pipeline/processing_result"
require_relative "csv_pipeline/lazy_processing_result"

module CsvPipeline
  EMAIL_PATTERN = Patterns::EMAIL

  NormalizeEmail = Rules::NormalizeEmail
  DefaultValue = Rules::DefaultValue
  Presence = Rules::Presence
  Format = Rules::Format
  EmailFormat = Rules::EmailFormat

  class << self
    def process(source, pipeline, **options)
      pipeline.process(source, **options)
    end

    def build(&block)
      Pipeline.build(&block)
    end

    def customer_pipeline
      Pipeline.customer_import
    end

    def from_yaml(source)
      Pipeline.from_yaml(source)
    end

    def from_schema(**options, &block)
      Pipeline.from_schema(**options, &block)
    end
  end
end
