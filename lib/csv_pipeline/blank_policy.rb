# frozen_string_literal: true

module CsvPipeline
  class BlankPolicy
    def self.only_nil
      new(treat_nil: true, empty_string: false, whitespace: false)
    end

    def self.default
      @default ||= new
    end

    def initialize(treat_nil: true, empty_string: true, whitespace: true)
      @nil_blank = treat_nil
      @empty_string_blank = empty_string
      @whitespace_blank = whitespace
    end

    def blank?(value)
      return true if @nil_blank && value.nil?
      return true if @empty_string_blank && value == ""
      return true if @whitespace_blank && value.is_a?(String) && value.strip.empty? && value != ""

      false
    end
  end
end
