# frozen_string_literal: true

require "csv_pipeline"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end

def build_customer_pipeline
  CsvPipeline::Pipeline.customer_import
end

def customers_csv_path
  File.expand_path("../examples/customers.csv", __dir__)
end

def build_record(**fields)
  CsvPipeline::Record.new(fields, row: 1)
end
