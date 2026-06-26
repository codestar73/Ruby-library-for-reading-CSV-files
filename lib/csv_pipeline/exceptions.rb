# frozen_string_literal: true

module CsvPipeline
  class Error < StandardError; end

  class FileNotFoundError < Error; end

  class ParseError < Error; end

  class ConfigurationError < Error; end
end
