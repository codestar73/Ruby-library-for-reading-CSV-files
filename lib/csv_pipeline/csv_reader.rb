# frozen_string_literal: true

require "csv"
require "stringio"

module CsvPipeline
  # Streams CSV rows one at a time, yielding {Record} objects with file line numbers.
  class CsvReader
    DEFAULT_OPTIONS = {
      headers: true,
      return_headers: false,
      strict_headers: false,
      encoding: "UTF-8"
    }.freeze

    def initialize(**options)
      @options = DEFAULT_OPTIONS.merge(options)
    end

    def each_record(source)
      return enum_for(:each_record, source) unless block_given?

      open_io(source) do |io|
        headers = nil
        line_number = 0

        if @options[:headers]
          unless io.eof?
            header_line = io.readline
            io.rewind
            headers = CSV.parse_line(header_line)
            HeaderValidator.validate!(headers) if @options[:strict_headers]
          end
          line_number = 1
        end

        CSV.new(io, **csv_options).each do |csv_row|
          line_number += 1

          if @options[:strict_headers]
            HeaderValidator.validate_row_shape!(headers, csv_row, line_number)
            validate_row_mapping!(csv_row.to_h, csv_row, line_number)
          end

          yield Record.new(csv_row.to_h, row: line_number)
        end
      end
    rescue CSV::MalformedCSVError => e
      raise ParseError, "malformed CSV: #{e.message}"
    end

    private

    def csv_options
      @options.slice(:headers, :return_headers, :col_sep, :row_sep, :quote_char)
    end

    def open_io(source)
      case source
      when String
        open_string_source(source) { |io| yield io }
      when IO, StringIO
        yield source
      else
        raise ArgumentError, "unsupported CSV source: #{source.class}"
      end
    end

    def open_string_source(string)
      if string.empty?
        yield StringIO.new("")
      elsif File.exist?(string)
        open_file_io(string) { |io| yield io }
      elsif csv_content?(string)
        yield StringIO.new(strip_bom(string))
      elsif path_like?(string)
        raise FileNotFoundError, "file not found: #{string}"
      else
        yield StringIO.new(strip_bom(string))
      end
    end

    def csv_content?(string)
      string.include?("\n") || string.include?(",") || string.include?("\r")
    end

    def path_like?(string)
      string.match?(/[\/\\]/) || string.match?(/\.csv\z/i)
    end

    def strip_bom(string)
      string.sub(/\A\xEF\xBB\xBF/, "").sub(/\A\uFEFF/, "")
    end

    def open_file_io(path)
      File.open(path, "rb") do |file|
        skip_utf8_bom!(file)
        file.set_encoding(@options[:encoding])
        yield file
      end
    end

    def skip_utf8_bom!(io)
      pos = io.pos
      bom = io.read(3)
      io.pos = pos
      io.pos = pos + 3 if bom == "\xEF\xBB\xBF".b
    end

    def validate_row_mapping!(data, csv_row, line_number)
      return unless @options[:headers]
      return unless data.empty? && csv_row.fields.compact.any?

      raise ParseError,
            "row #{line_number} could not be mapped to headers " \
            "(duplicate headers, ragged columns, or missing header row)"
    end
  end
end
