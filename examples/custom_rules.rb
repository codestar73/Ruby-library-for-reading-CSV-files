# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "csv_pipeline"

# Cross-field custom rule — only depends on #call(record).
class CompanyDomainRule
  ALLOWED_DOMAIN = "@example.com"

  def call(record)
    email = record[:email]
    return if CsvPipeline::Blank.blank?(email)
    return if email.end_with?(ALLOWED_DOMAIN)

    record.add_error(
      :email,
      "must use the company domain",
      code: :invalid_domain,
      value: email
    )
  end
end

pipeline = CsvPipeline::Pipeline.new([
  CsvPipeline::NormalizeEmail.new(:email),
  CsvPipeline::DefaultValue.new(:name, "empty"),
  CsvPipeline::Presence.new(:email),
  CsvPipeline::Format.new(:email, CsvPipeline::EMAIL_PATTERN),
  CompanyDomainRule.new
])

csv = <<~CSV
  name,email
  Alice,alice@example.com
  Mallory,mallory@other.com
CSV

result = pipeline.process(csv)

result.invalid_records.each do |record|
  puts "Line #{record.row}: #{record.errors.map(&:message).join(', ')}"
end
