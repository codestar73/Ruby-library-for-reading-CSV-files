# frozen_string_literal: true

module CsvPipeline
  # Contract for pipeline rules. Any object responding to +call(record)+ is valid.
  #
  # @see Record
  module Rule
    def call(record)
      raise NotImplementedError, "#{self.class} must implement #call(record)"
    end
  end
end
