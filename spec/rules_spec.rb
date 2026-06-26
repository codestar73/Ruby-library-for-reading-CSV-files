# frozen_string_literal: true

RSpec.describe CsvPipeline::Rules::NormalizeEmail do
  subject(:rule) { described_class.new(:email) }

  it "downcases and strips email values" do
    record = build_record(email: "  JOHN.DOE@EXAMPLE.COM ")
    rule.call(record)

    expect(record[:email]).to eq("john.doe@example.com")
  end

  it "normalizes uppercase email" do
    record = build_record(email: "USER@EXAMPLE.COM")
    rule.call(record)

    expect(record[:email]).to eq("user@example.com")
  end

  it "leaves nil unchanged" do
    record = build_record(email: nil)
    rule.call(record)

    expect(record[:email]).to be_nil
  end

  it "does not treat empty strings as nil" do
    record = build_record(email: "")
    rule.call(record)

    expect(record[:email]).to eq("")
  end
end

RSpec.describe CsvPipeline::Rules::DefaultValue do
  subject(:rule) { described_class.new(:name, "empty") }

  it "applies the default to nil" do
    record = build_record(name: nil)
    rule.call(record)

    expect(record[:name]).to eq("empty")
  end

  it "applies the default to empty strings" do
    record = build_record(name: "")
    rule.call(record)

    expect(record[:name]).to eq("empty")
  end

  it "applies the default to whitespace-only strings" do
    record = build_record(name: "   ")
    rule.call(record)

    expect(record[:name]).to eq("empty")
  end

  it "does not overwrite nonblank values" do
    record = build_record(name: "Alice")
    rule.call(record)

    expect(record[:name]).to eq("Alice")
  end
end

RSpec.describe CsvPipeline::Rules::Presence do
  subject(:rule) { described_class.new(:email) }

  it "passes when the value is present" do
    record = build_record(email: "user@example.com")
    rule.call(record)

    expect(record).to be_valid
  end

  it "adds an error for nil" do
    record = build_record(email: nil)
    rule.call(record)

    expect(record.errors.first).to have_attributes(
      field: :email,
      message: "must be present",
      code: :blank,
      rule: "Presence"
    )
  end

  it "adds an error for empty strings" do
    record = build_record(email: "")
    rule.call(record)

    expect(record.errors.first.message).to eq("must be present")
  end

  it "adds an error for whitespace-only strings" do
    record = build_record(email: "   ")
    rule.call(record)

    expect(record.errors.first.message).to eq("must be present")
  end
end

RSpec.describe CsvPipeline::Rules::Format do
  subject(:rule) { described_class.new(:email, /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/) }

  it "passes when the value matches the pattern" do
    record = build_record(email: "user@example.com")
    rule.call(record)

    expect(record).to be_valid
  end

  it "adds an error when the value does not match" do
    record = build_record(email: "not-an-email")
    rule.call(record)

    expect(record.errors.first).to have_attributes(
      field: :email,
      code: :invalid_format,
      message: "has an invalid format",
      value: "not-an-email",
      rule: "Format"
    )
  end

  it "skips blank values by default" do
    record = build_record(email: "")
    rule.call(record)

    expect(record).to be_valid
  end

  it "can validate blank values when skip_blank is false" do
    rule = described_class.new(:email, /@/, skip_blank: false)
    record = build_record(email: "")
    rule.call(record)

    expect(record.errors.first.code).to eq(:invalid_format)
  end

  it "supports a custom message" do
    rule = described_class.new(:email, /@/, message: "must look like an email")
    record = build_record(email: "nope")
    rule.call(record)

    expect(record.errors.first.message).to eq("must look like an email")
  end
end

RSpec.describe CsvPipeline::Blank do
  it "defines blank consistently" do
    expect(described_class.blank?(nil)).to be true
    expect(described_class.blank?("")).to be true
    expect(described_class.blank?("   ")).to be true
    expect(described_class.blank?("value")).to be false
  end
end

RSpec.describe CsvPipeline::Rules::BlockRule do
  it "does not swallow ArgumentError from transform blocks" do
    pipeline = CsvPipeline::Pipeline.new([
      described_class.new(:x, :transform, ->(_v) { raise ArgumentError, "intentional" })
    ])

    expect do
      pipeline.run(CsvPipeline::Record.new({ "x" => 1 }, row: 1))
    end.to raise_error(ArgumentError, "intentional")
  end

  it "supports plain callable objects without arity" do
    reverser = Class.new do
      def call(value)
        value.reverse
      end
    end

    pipeline = CsvPipeline.build { |p| p.transform(:code, reverser.new) }
    record = pipeline.run(CsvPipeline::Record.new({ code: "abc" }, row: 1))

    expect(record[:code]).to eq("cba")
  end
end

RSpec.describe CsvPipeline::Rules::EmailFormat do
  it "validates email shape with a descriptive message" do
    rule = described_class.new(:email)
    record = build_record(email: "not-an-email")
    rule.call(record)

    expect(record.errors.first).to have_attributes(
      code: :invalid_format,
      message: "has an invalid email format",
      rule: "EmailFormat"
    )
  end
end
