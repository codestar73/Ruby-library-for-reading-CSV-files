# frozen_string_literal: true

RSpec.describe CsvPipeline::Pipeline do
  let(:pipeline) do
    described_class.new([
      CsvPipeline::NormalizeEmail.new(:email),
      CsvPipeline::Presence.new(:email)
    ])
  end

  describe "#initialize" do
    it "accepts an ordered array of rules" do
      expect(pipeline.rules.size).to eq(2)
    end

    it "rejects invalid rules" do
      expect { described_class.new([Object.new]) }
        .to raise_error(CsvPipeline::ConfigurationError, /must respond to #call/)
    end
  end

  describe "#run" do
    it "executes rules in configuration order" do
      order = []
      first = Class.new do
        define_method(:call) { |record| order << :first }
      end
      second = Class.new do
        define_method(:call) { |record| order << :second }
      end

      described_class.new([first.new, second.new]).run(build_record)

      expect(order).to eq(%i[first second])
    end

    it "makes transformations visible to later rules" do
      record = build_record(email: "  USER@EXAMPLE.COM  ")
      pipeline.run(record)

      expect(record[:email]).to eq("user@example.com")
      expect(record).to be_valid
    end

    it "continues after validation errors" do
      record = build_record(email: "")
      pipeline.run(record)

      expect(record[:email]).to eq("")
      expect(record.errors.size).to eq(1)
    end

    it "collects multiple errors on different fields" do
      multi = described_class.new([
        CsvPipeline::Presence.new(:name),
        CsvPipeline::Presence.new(:email)
      ])

      record = multi.run(build_record(name: "", email: ""))

      expect(record.errors.map(&:field)).to eq(%i[name email])
    end

    it "does not share errors between records" do
      first = pipeline.run(build_record(email: ""))
      second = pipeline.run(build_record(email: "user@example.com"))

      expect(first).to be_invalid
      expect(second).to be_valid
    end

    it "classifies records with no errors as valid" do
      record = pipeline.run(build_record(email: "user@example.com"))

      expect(record).to be_valid
    end

    it "classifies records with errors as invalid" do
      record = pipeline.run(build_record(email: ""))

      expect(record).to be_invalid
    end

    it "accepts custom rules without modifying library code" do
      custom = Class.new do
        def call(record)
          record.add_error(:email, "must use the company domain", code: :invalid_domain)
        end
      end

      record = described_class.new([custom.new]).run(build_record(email: "x@y.com"))

      expect(record.errors.first.code).to eq(:invalid_domain)
    end

    it "propagates unexpected errors from custom rules" do
      boom = Class.new { define_method(:call) { |_r| raise "bug in rule" } }

      expect do
        described_class.new([boom.new]).run(CsvPipeline::Record.new({}, row: 1))
      end.to raise_error(RuntimeError, "bug in rule")
    end

    it "supports fresh copies for re-processing" do
      p = described_class.new([CsvPipeline::Presence.new(:email)])
      original = CsvPipeline::Record.new({ email: "" }, row: 1)

      p.run(original)
      fresh = p.run(original, fresh: true)

      expect(original.errors.size).to eq(1)
      expect(fresh.errors.size).to eq(1)
      expect(fresh).not_to equal(original)
    end
  end

  describe "#each_processed_record" do
    it "streams records without materializing a result" do
      seen = 0
      build_customer_pipeline.each_processed_record(customers_csv_path) { seen += 1 }

      expect(seen).to eq(6)
    end
  end

  describe "#process" do
    it "processes an enumerable of records separately from CSV reading" do
      rows = [
        { name: "Alice", email: "  ALICE@EXAMPLE.COM  " },
        { name: "Bob", email: "" }
      ]

      result = pipeline.process(rows)

      expect(result.valid_count).to eq(1)
      expect(result.invalid_count).to eq(1)
      expect(result.first[:email]).to eq("alice@example.com")
    end

    it "composes reusable pipeline fragments with +" do
      transforms = described_class.new([CsvPipeline::NormalizeEmail.new(:email)])
      validations = described_class.new([CsvPipeline::Presence.new(:email)])
      combined = transforms + validations

      record = combined.run(build_record(email: "  USER@EXAMPLE.COM  "))

      expect(record[:email]).to eq("user@example.com")
      expect(record).to be_valid
    end

    it "returns a lazy result when materialize is false" do
      result = build_customer_pipeline.process(customers_csv_path, materialize: false)

      expect(result).to be_a(CsvPipeline::LazyProcessingResult)
      expect(result.summary).to eq(total: 6, valid: 3, invalid: 3, error_count: 3)
    end
  end

  describe ".customer_import" do
    it "matches the customers.csv integration expectations" do
      result = described_class.customer_import.process(customers_csv_path)

      expect(result.summary).to eq(total: 6, valid: 3, invalid: 3, error_count: 3)
    end
  end

  describe ".build DSL" do
    it "supports field grouping and inline blocks" do
      built = described_class.build do |p|
        p.field :email do |f|
          f.transform CsvPipeline::NormalizeEmail
          f.validate CsvPipeline::Presence
        end
      end

      record = built.run(build_record(email: "  USER@EXAMPLE.COM  "))

      expect(record[:email]).to eq("user@example.com")
      expect(record).to be_valid
    end

    it "supports single-argument transform blocks" do
      built = described_class.build do |p|
        p.transform(:name, &:upcase)
      end

      record = built.run(build_record(name: "alice"))

      expect(record[:name]).to eq("ALICE")
    end

    it "supports EmailFormat without an explicit pattern" do
      built = described_class.build do |p|
        p.field(:email) { |f| f.validate CsvPipeline::EmailFormat }
      end

      record = built.run(CsvPipeline::Record.new({ email: "bad" }, row: 1))

      expect(record).to be_invalid
      expect(record.errors.first.rule).to eq("EmailFormat")
    end

    it "applies optional defaults after required validations" do
      built = described_class.build do |p|
        p.required :email do |f|
          f.validate CsvPipeline::Presence
        end
        p.optional :name, default: "empty"
      end

      record = built.run(CsvPipeline::Record.new({ name: nil, email: "a@x.com" }, row: 1))

      expect(record).to be_valid
      expect(record[:name]).to eq("empty")
    end
  end
end

RSpec.describe CsvPipeline::Record do
  it "stores structured errors in rule order" do
    record = build_record
    record.add_error(:email, "must be present", code: :blank)
    record.add_error(:email, "has an invalid format", code: :invalid_format)

    expect(record.errors.map(&:code)).to eq(%i[blank invalid_format])
    expect(record.errors_by_field).to eq(
      email: ["must be present", "has an invalid format"]
    )
  end

  it "serializes errors with row, field, code, message, and value" do
    record = CsvPipeline::Record.new({ email: "bad" }, row: 5)
    record.add_error(:email, "has an invalid format", code: :invalid_format, value: "bad")

    expect(record.errors.first.to_h).to eq(
      row: 5,
      field: :email,
      code: :invalid_format,
      message: "has an invalid format",
      value: "bad"
    )
  end

  it "returns a frozen copy of errors" do
    record = CsvPipeline::Record.new({ name: "Alice" }, row: 1)
    record.add_error(:email, "missing", code: :blank, rule: "Presence")

    expect(record.errors).to be_frozen
    expect { record.errors << :tampered }.to raise_error(FrozenError)
  end

  it "tracks changed fields against source data" do
    record = CsvPipeline::Record.new({ email: "  A@B.COM  " }, row: 1)
    CsvPipeline::NormalizeEmail.new(:email).call(record)

    expect(record.changed_fields).to eq("email" => { from: "  A@B.COM  ", to: "a@b.com" })
    expect(record.changed?(:email)).to be true
  end
end

RSpec.describe CsvPipeline::ProcessingResult do
  let(:result) { build_customer_pipeline.process(customers_csv_path) }

  it "exposes valid and invalid records" do
    expect(result.valid_records.size).to eq(3)
    expect(result.invalid_records.size).to eq(3)
  end

  it "returns a summary" do
    expect(result.summary).to eq(total: 6, valid: 3, invalid: 3, error_count: 3)
  end

  it "groups errors by row" do
    expect(result.errors_by_row.keys).to contain_exactly(5, 6, 7)
  end

  it "exposes valid and invalid hashes" do
    expect(result.valid_hashes).to all(be_a(Hash))
    expect(result.valid_hashes.size).to eq(3)
    expect(result.invalid_hashes.size).to eq(3)
  end

  it "serializes errors as JSON-ready hashes" do
    expect(result.errors_json).to all(include(:field, :code, :message))
  end

  it "includes changed fields in serialized output" do
    payload = result.to_h[:records].find { |entry| entry[:data]["name"] == "Bob" }

    expect(payload[:changed_fields]["email"][:to]).to eq("bob@example.com")
    expect(payload[:changed_fields]["email"][:from]).to include("BOB@EXAMPLE.COM")
  end
end
