# frozen_string_literal: true

module CsvPipeline
  class ValidationError
    attr_reader :row, :field, :code, :message, :value, :rule

    def initialize(row:, field:, code:, message:, value: nil, rule: nil)
      @row = row
      @field = field.to_sym
      @code = code.to_sym
      @message = message
      @value = value
      @rule = rule
    end

    def to_s
      location = row ? "line #{row}: " : ""
      rule_label = rule ? "[#{rule}] " : ""
      "#{location}#{rule_label}#{field}: #{message}"
    end

    def to_h
      { row: row, field: field, code: code, message: message, value: value, rule: rule }.compact
    end

    def ==(other)
      other.is_a?(ValidationError) && to_h == other.to_h
    end
  end
end
