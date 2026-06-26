# frozen_string_literal: true

RSpec.describe "advanced features" do
  after do
    CsvPipeline::Blank.policy = CsvPipeline::BlankPolicy.default
    CsvPipeline::Messages.reset!
  end

  describe "fail-fast mode" do
    it "stops after the first validation error" do
      pipeline = CsvPipeline::Pipeline.new(
        [
          CsvPipeline::Presence.new(:name),
          CsvPipeline::Presence.new(:email)
        ],
        fail_fast: true
      )

      record = pipeline.run(build_record(name: "", email: ""))

      expect(record.errors.map(&:field)).to eq([:name])
    end
  end

  describe "conditional rules" do
    it "runs nested rules only when the predicate matches" do
      pipeline = CsvPipeline::Pipeline.build do |p|
        p.when(->(record) { record[:country] == "US" }) do |w|
          w.validate :zip, CsvPipeline::Presence
        end
      end

      us = pipeline.run(build_record(country: "US", zip: ""))
      uk = pipeline.run(build_record(country: "UK", zip: ""))

      expect(us).to be_invalid
      expect(uk).to be_valid
    end
  end

  describe CsvPipeline::Schema do
    it "builds a pipeline from cross-field schema definitions" do
      match_rule = Class.new do
        def call(record)
          return if record[:name].to_s.downcase == record[:email].to_s.split("@").first

          record.add_error(:email, "must match name", code: :cross_field)
        end
      end.new

      pipeline = CsvPipeline::Schema.build do |schema|
        schema.required :email
        schema.normalize_email :email
        schema.optional :name, default: "empty"
        schema.cross_field match_rule
      end

      valid = pipeline.run(build_record(name: "Alice", email: "alice@example.com"))
      invalid = pipeline.run(build_record(name: "Bob", email: "alice@example.com"))

      expect(valid).to be_valid
      expect(invalid.errors.map(&:code)).to include(:cross_field)
    end
  end

  describe CsvPipeline::YamlLoader do
    it "loads a pipeline from YAML" do
      path = File.expand_path("../examples/customers.pipeline.yml", __dir__)
      pipeline = CsvPipeline::Pipeline.from_yaml(path)
      result = pipeline.process(customers_csv_path)

      expect(result.valid_count).to eq(3)
      expect(result.invalid_count).to eq(3)
    end

    it "supports conditional rules in YAML" do
      yaml = <<~YAML
        rules:
          - type: conditional
            field: zip
            if:
              field: country
              equals: US
            then: presence
      YAML

      pipeline = CsvPipeline::Pipeline.from_yaml(yaml)
      us = pipeline.run(build_record(country: "US", zip: ""))
      uk = pipeline.run(build_record(country: "UK", zip: ""))

      expect(us).to be_invalid
      expect(uk).to be_valid
    end
  end

  describe "JSON and CSV export" do
    let(:result) { build_customer_pipeline.process(customers_csv_path) }

    it "serializes the full result to JSON" do
      payload = JSON.parse(result.to_json)

      expect(payload["summary"]["total"]).to eq(6)
      expect(payload["records"].size).to eq(6)
    end

    it "writes CSV output with an errors column" do
      output = StringIO.new
      result.write_csv(output)

      rows = CSV.parse(output.string, headers: true)
      david = rows.find { |row| row["name"] == "David" }

      expect(rows.headers).to include("errors")
      expect(david["errors"]).to include("invalid format")
    end

    it "writes CSV output to a file path" do
      path = File.expand_path("../tmp/export_test.csv", __dir__)
      FileUtils.mkdir_p(File.dirname(path))
      result.write_csv(path)

      rows = CSV.read(path, headers: true)
      expect(rows.size).to eq(6)
      expect(rows.headers).to include("errors")
    ensure
      File.delete(path) if path && File.exist?(path)
    end
  end

  describe "configurable blank semantics" do
    it "treats only nil as blank when configured" do
      CsvPipeline::Blank.configure(treat_nil: true, empty_string: false, whitespace: false)

      pipeline = CsvPipeline::Pipeline.new([CsvPipeline::DefaultValue.new(:name, "empty")])
      record = pipeline.run(build_record(name: ""))

      expect(record[:name]).to eq("")
    end

    it "treats whitespace-only strings as blank by default" do
      pipeline = CsvPipeline::Pipeline.new([CsvPipeline::DefaultValue.new(:name, "empty")])
      record = pipeline.run(build_record(name: "   "))

      expect(record[:name]).to eq("empty")
    end
  end

  describe CsvPipeline::Messages do
    it "returns localized default validation messages" do
      CsvPipeline::Messages.locale = :es
      rule = CsvPipeline::Presence.new(:email)
      record = build_record(email: "")
      rule.call(record)

      expect(record.errors.first.message).to eq("debe estar presente")
    end

    it "allows custom translations" do
      CsvPipeline::Messages.add(:en, :blank, "is required")
      rule = CsvPipeline::Presence.new(:email)
      record = build_record(email: "")
      rule.call(record)

      expect(record.errors.first.message).to eq("is required")
    end
  end
end
