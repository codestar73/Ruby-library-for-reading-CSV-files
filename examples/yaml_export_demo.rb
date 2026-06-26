# frozen_string_literal: true

require "csv"
require "fileutils"
require "json"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "csv_pipeline"

examples_dir = __dir__
csv_path = File.expand_path("customers.csv", examples_dir)
yaml_path = File.expand_path("customers.pipeline.yml", examples_dir)
output_dir = File.expand_path("output", examples_dir)
csv_output = File.join(output_dir, "customers_with_errors.csv")
json_output = File.join(output_dir, "customers_report.json")

FileUtils.mkdir_p(output_dir)

puts "Loading pipeline from #{File.basename(yaml_path)}..."
pipeline = CsvPipeline.from_yaml(yaml_path)

puts "Processing #{File.basename(csv_path)}..."
result = pipeline.process(csv_path)

puts
puts "Summary: #{result.summary}"
puts

puts "Writing CSV with errors column -> #{csv_output}"
result.write_csv(csv_output)

puts "Writing JSON report -> #{json_output}"
File.write(json_output, result.to_json(pretty: true))

puts
puts "CSV preview (first 3 rows):"
CSV.read(csv_output, headers: true).first(3).each_with_index do |row, index|
  errors = row["errors"].to_s.empty? ? "(none)" : row["errors"]
  puts "  #{index + 1}. #{row['name'].inspect} | #{row['email'].inspect} | errors: #{errors}"
end

puts
puts "JSON summary:"
puts JSON.pretty_generate(result.summary)
