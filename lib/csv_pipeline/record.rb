# frozen_string_literal: true

module CsvPipeline
  # Wraps one CSV row: mutable field values, attached validation errors, and row metadata.
  class Record
    attr_reader :row, :source_data

    def initialize(data, row: nil)
      @row = row
      @data = normalize_keys(data)
      @source_data = @data.dup.freeze
      @errors = []
    end

    def [](field)
      @data[field.to_s]
    end

    def []=(field, value)
      @data[field.to_s] = value
    end

    def fetch(field, default = nil)
      @data.fetch(field.to_s, default)
    end

    def key?(field)
      @data.key?(field.to_s)
    end

    def add_error(field, message, code: :validation_error, value: nil, rule: nil)
      current = value.nil? ? self[field] : value
      @errors << ValidationError.new(
        row: row,
        field: field,
        code: code,
        message: message,
        value: current,
        rule: rule
      )
      self
    end

    def errors
      @errors.dup.freeze
    end

    def valid?
      @errors.empty?
    end

    def invalid?
      !valid?
    end

    def errors_for(field)
      @errors.select { |error| error.field == field.to_sym }
    end

    def errors_by_field
      @errors.group_by(&:field).transform_values { |field_errors| field_errors.map(&:message) }
    end

    def changed?(field = nil)
      return changed_fields.any? if field.nil?

      changed_fields.key?(field.to_s)
    end

    def changed_fields
      to_h.each_with_object({}) do |(field, value), changes|
        original = @source_data[field]
        next if original == value

        changes[field] = { from: original, to: value }
      end
    end

    def fresh_copy
      self.class.new(@source_data.dup, row: row)
    end

    def to_h
      @data.dup
    end

    def to_s
      "#<#{self.class} row=#{row} data=#{to_h.inspect} errors=#{@errors.size}>"
    end

    private

    def normalize_keys(hash)
      hash.each_with_object({}) do |(key, value), normalized|
        normalized[key.to_s] = value
      end
    end
  end
end
