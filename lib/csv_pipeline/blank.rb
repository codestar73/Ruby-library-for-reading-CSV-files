# frozen_string_literal: true

module CsvPipeline
  module Blank
    @policy = BlankPolicy.default

    module_function

    def policy
      @policy
    end

    def policy=(policy)
      @policy = policy
    end

    def configure(treat_nil: true, empty_string: true, whitespace: true)
      @policy = BlankPolicy.new(treat_nil: treat_nil, empty_string: empty_string, whitespace: whitespace)
    end

    def blank?(value)
      @policy.blank?(value)
    end

    def present?(value)
      !blank?(value)
    end
  end
end
