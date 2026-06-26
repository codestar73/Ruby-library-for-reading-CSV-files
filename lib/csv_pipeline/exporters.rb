# frozen_string_literal: true

require "csv"
require "json"

module CsvPipeline
  module Exporters
    module_function

    def result_to_json(result, pretty: false)
      payload = result.to_h
      pretty ? JSON.pretty_generate(payload) : JSON.generate(payload)
    end

    def write_csv(result, output, errors_column: "errors")
      field_headers = result.flat_map { |record| record.to_h.keys }.uniq
      headers = field_headers + [errors_column]

      write_rows = lambda do |csv|
        result.each do |record|
          row = field_headers.map { |field| record[field] }
          row << errors_cell(record)
          csv << row
        end
      end

      if output.respond_to?(:write)
        csv = CSV.new(output, write_headers: true, headers: headers)
        write_rows.call(csv)
      else
        CSV.open(output.to_s, "w", write_headers: true, headers: headers, &write_rows)
      end
    end

    def errors_cell(record)
      return "" if record.valid?

      record.errors.map(&:to_s).join("; ")
    end
  end
end
