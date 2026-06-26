# frozen_string_literal: true

module CsvPipeline
  class HeaderValidator
    HEADER_ROW = 1

    class << self
      def validate!(headers)
        raise ParseError, "missing header row" if headers.nil?

        if headers.any? { |header| header.nil? || header.to_s.strip.empty? }
          raise ParseError, "blank header name on header row: #{headers.inspect}"
        end

        compact = headers.compact
        raise ParseError, "missing header row" if compact.empty?

        return if compact.size == compact.uniq.size

        duplicates = compact.tally.select { |_, count| count > 1 }.keys
        raise ParseError, "duplicate headers on header row: #{duplicates.inspect}"
      end

    def validate_row_shape!(headers, csv_row, line_number)
      return if headers.nil? || headers.empty?

      expected = headers.size
      actual = csv_row.fields.size
      return if actual <= expected

      raise ParseError,
            "row #{line_number} has #{actual} columns, expected at most #{expected}"
    end
    end
  end
end
