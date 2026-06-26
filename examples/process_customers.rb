# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "csv_pipeline"
require_relative "customer_pipeline"

result = CustomerPipeline.process(File.expand_path("customers.csv", __dir__))

puts result.summary
puts

result.each do |record|
  status = record.valid? ? "OK" : "ERR"
  puts "[#{status}] line #{record.row}: #{record.to_h.inspect}"

  unless record.changed_fields.empty?
    puts "       changed: #{record.changed_fields.inspect}"
  end

  record.errors.each do |error|
    puts "       #{error.to_h}"
  end
end
