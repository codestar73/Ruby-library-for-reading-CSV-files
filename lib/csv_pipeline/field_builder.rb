# frozen_string_literal: true

module CsvPipeline
  class FieldBuilder
    def initialize(pipeline, field)
      @pipeline = pipeline
      @field = field
    end

    def transform(rule = nil, **options, &block)
      @pipeline.transform(@field, rule, **options, &block)
    end

    def validate(rule = nil, **options, &block)
      @pipeline.validate(@field, rule, **options, &block)
    end
  end
end
