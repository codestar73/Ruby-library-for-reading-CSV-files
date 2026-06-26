# frozen_string_literal: true

module CsvPipeline
  module Rules
    class Conditional
      def initialize(predicate, rule)
        @predicate = predicate
        @rule = rule
      end

      def call(record)
        return unless @predicate.call(record)

        @rule.call(record)
      end
    end
  end
end
