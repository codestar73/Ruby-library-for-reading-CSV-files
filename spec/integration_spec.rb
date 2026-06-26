# frozen_string_literal: true

RSpec.describe "customers.csv integration" do
  let(:result) { build_customer_pipeline.process(customers_csv_path) }

  it "leaves Alice valid" do
    alice = result.records.find { |record| record[:name] == "Alice" }

    expect(alice).to be_valid
    expect(alice.row).to eq(2)
  end

  it "normalizes Bob's email" do
    bob = result.records.find { |record| record[:name] == "Bob" }

    expect(bob).to be_valid
    expect(bob[:email]).to eq("bob@example.com")
  end

  it "defaults Carol's blank name to empty" do
    carol = result.records.find { |record| record[:email] == "carol@example.com" }

    expect(carol).to be_valid
    expect(carol[:name]).to eq("empty")
  end

  it "reports David's email format error on line 5" do
    david = result.records.find { |record| record[:name] == "David" }

    expect(david).to be_invalid
    expect(david.row).to eq(5)
    expect(david.errors.first).to have_attributes(
      field: :email,
      code: :invalid_format,
      value: "not-an-email"
    )
  end

  it "reports Eve's email presence error on line 6" do
    eve = result.records.find { |record| record[:name] == "Eve" }

    expect(eve).to be_invalid
    expect(eve.row).to eq(6)
    expect(eve.errors.first).to have_attributes(
      field: :email,
      code: :blank
    )
  end

  it "defaults the final row's blank name and reports an email format error" do
    final_row = result.records.last

    expect(final_row[:name]).to eq("empty")
    expect(final_row[:email]).to eq("invalid@")
    expect(final_row).to be_invalid
    expect(final_row.row).to eq(7)
    expect(final_row.errors.map(&:code)).to eq([:invalid_format])
  end

  it "returns deterministic valid and invalid counts" do
    expect(result.summary).to eq(total: 6, valid: 3, invalid: 3, error_count: 3)
  end

  it "preserves error order according to rule execution" do
    pipeline = CsvPipeline::Pipeline.new([
      CsvPipeline::Presence.new(:email),
      CsvPipeline::Format.new(:email, CsvPipeline::EMAIL_PATTERN)
    ])

    record = pipeline.run(CsvPipeline::Record.new({ email: "bad" }, row: 10))

    expect(record.errors.map(&:code)).to eq(%i[invalid_format])
  end

  it "does not produce duplicate format errors for blank email when presence runs first" do
    record = build_customer_pipeline.run(CsvPipeline::Record.new({ name: "Eve", email: nil }, row: 6))

    expect(record.errors.map(&:code)).to eq([:blank])
  end
end

RSpec.describe "custom record-level rules" do
  it "validates cross-field business logic without modifying the library" do
    rule = Class.new do
      def call(record)
        return if CsvPipeline::Blank.present?(record[:email])
        return if CsvPipeline::Blank.present?(record[:phone])

        record.add_error(:email, "email or phone must be present", code: :contact_missing)
      end
    end

    pipeline = CsvPipeline::Pipeline.new([rule.new])
    record = pipeline.run(CsvPipeline::Record.new({ name: "Alice" }, row: 1))

    expect(record.errors.first.code).to eq(:contact_missing)
  end
end
