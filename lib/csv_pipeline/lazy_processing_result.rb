# frozen_string_literal: true

module CsvPipeline
  class LazyProcessingResult
    include Enumerable

    def initialize(source, pipeline, reader: CsvReader.new)
      @source = source
      @pipeline = pipeline
      @reader = reader
    end

    def each(&block)
      return enum_for(:each) unless block_given?

      @pipeline.each_processed_record(@source, reader: @reader, &block)
    end

    def summary
      tallies = { total: 0, valid: 0, invalid: 0, error_count: 0 }

      each do |record|
        tallies[:total] += 1
        if record.valid?
          tallies[:valid] += 1
        else
          tallies[:invalid] += 1
          tallies[:error_count] += record.errors.size
        end
      end

      tallies
    end

    def to_a
      records = []
      each { |record| records << record }
      records
    end

    def materialize
      ProcessingResult.new(to_a)
    end

    def to_json(pretty: false)
      materialize.to_json(pretty: pretty)
    end

    def write_csv(output, errors_column: "errors")
      materialize.write_csv(output, errors_column: errors_column)
    end
  end
end
