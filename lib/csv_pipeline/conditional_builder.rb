# frozen_string_literal: true

module CsvPipeline
  class ConditionalBuilder
    def initialize(pipeline, predicate)
      @pipeline = pipeline
      @predicate = predicate
    end

    def transform(field, rule = nil, **options, &block)
      rule_object = @pipeline.send(:build_field_rule, field, rule, :transform, options, block)
      @pipeline.add(Rules::Conditional.new(@predicate, rule_object))
    end

    def validate(field, rule = nil, **options, &block)
      rule_object = @pipeline.send(:build_field_rule, field, rule, :validate, options, block)
      @pipeline.add(Rules::Conditional.new(@predicate, rule_object))
    end

    def add(rule)
      @pipeline.add(Rules::Conditional.new(@predicate, rule))
    end
  end
end
