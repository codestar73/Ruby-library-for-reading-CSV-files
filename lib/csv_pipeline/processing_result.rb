# frozen_string_literal: true

module CsvPipeline
  class ProcessingResult
    include Enumerable

    def initialize(records)
      @records = records
    end

    attr_reader :records

    def each(&block)
      @records.each(&block)
    end

    def valid_records
      select(&:valid?)
    end

    def invalid_records
      select(&:invalid?)
    end

    def valid_hashes
      valid_records.map(&:to_h)
    end

    def invalid_hashes
      invalid_records.map(&:to_h)
    end

    def errors
      flat_map(&:errors)
    end

    def errors_json
      errors.map(&:to_h)
    end

    def errors_by_row
      invalid_records.each_with_object({}) do |record, grouped|
        grouped[record.row] = record.errors
      end
    end

    def valid_count
      count(&:valid?)
    end

    def invalid_count
      count(&:invalid?)
    end

    def total_count
      @records.size
    end

    def summary
      {
        total: total_count,
        valid: valid_count,
        invalid: invalid_count,
        error_count: errors.size
      }
    end

    def to_h
      {
        summary: summary,
        records: map { |record| serialize_record(record) }
      }
    end

    def to_json(pretty: false)
      Exporters.result_to_json(self, pretty: pretty)
    end

    def write_csv(output, errors_column: "errors")
      Exporters.write_csv(self, output, errors_column: errors_column)
    end

    private

    def serialize_record(record)
      {
        row: record.row,
        data: record.to_h,
        source_data: record.source_data,
        changed_fields: record.changed_fields,
        valid: record.valid?,
        errors: record.errors.map(&:to_h)
      }
    end
  end

  Report = ProcessingResult
end
