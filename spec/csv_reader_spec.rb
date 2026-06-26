# frozen_string_literal: true

require "stringio"

RSpec.describe CsvPipeline::CsvReader do
  subject(:reader) { described_class.new }

  describe "#each_record" do
    it "maps headers to record fields" do
      csv = "name,email\nAlice,alice@example.com\n"
      records = reader.each_record(csv).to_a

      expect(records.first[:name]).to eq("Alice")
      expect(records.first[:email]).to eq("alice@example.com")
    end

    it "assigns file line numbers with the header on line 1" do
      csv = "name,email\nAlice,a@x.com\nBob,b@x.com\n"
      rows = reader.each_record(csv).map(&:row)

      expect(rows).to eq([2, 3])
    end

    it "streams one row at a time" do
      csv = "name,email\nAlice,a@x.com\nBob,b@x.com\n"
      seen = 0

      reader.each_record(csv) { seen += 1 }

      expect(seen).to eq(2)
    end

    it "handles blank cells as nil" do
      csv = "name,email\nAlice,\n"
      record = reader.each_record(csv).first

      expect(record[:email]).to be_nil
    end

    it "handles quoted values containing commas" do
      csv = "name,email\n\"Alice, Jr.\",alice@example.com\n"
      record = reader.each_record(csv).first

      expect(record[:name]).to eq("Alice, Jr.")
    end

    it "returns no records for an empty file" do
      expect(reader.each_record("").to_a).to be_empty
    end

    it "returns no records for a header-only file" do
      csv = "name,email\n"
      expect(reader.each_record(csv).to_a).to be_empty
    end

    it "reads from a file path" do
      records = reader.each_record(customers_csv_path).to_a

      expect(records.size).to eq(6)
    end

    it "reads from IO objects" do
      io = StringIO.new("name,email\nAlice,alice@example.com\n")
      record = reader.each_record(io).first

      expect(record[:name]).to eq("Alice")
    end

    it "raises for missing files" do
      expect { reader.each_record("missing/file.csv").to_a }
        .to raise_error(CsvPipeline::FileNotFoundError, /file not found/)
    end

    it "raises for malformed CSV" do
      malformed = "name,email\n\"unclosed,alice@example.com\n"

      expect { reader.each_record(malformed).to_a }
        .to raise_error(CsvPipeline::ParseError, /malformed CSV/)
    end

    it "treats bare tokens as inline CSV content" do
      expect { reader.each_record("singlevalue").to_a }.not_to raise_error
    end

    it "raises FileNotFoundError for path-like missing files" do
      expect { reader.each_record("missing/customers.csv").to_a }
        .to raise_error(CsvPipeline::FileNotFoundError, /file not found/)
    end

    it "strips a UTF-8 BOM from headers" do
      csv = "\uFEFFname,email\nAlice,alice@example.com\n"
      record = reader.each_record(csv).first

      expect(record.key?(:name)).to be true
      expect(record[:name]).to eq("Alice")
    end
  end

  describe "strict_headers: true" do
    subject(:strict) { described_class.new(strict_headers: true) }

    it "reports duplicate headers on the header row" do
      csv = "name,name\nAlice,Bob\n"

      expect { strict.each_record(csv).to_a }
        .to raise_error(CsvPipeline::ParseError, /duplicate headers on header row/)
    end

    it "rejects rows with extra columns" do
      csv = "name,email\nAlice,a@x.com,extra\n"

      expect { strict.each_record(csv).to_a }
        .to raise_error(CsvPipeline::ParseError, /has 3 columns/)
    end

    it "rejects blank header names" do
      csv = ",email\nAlice,a@x.com\n"

      expect { strict.each_record(csv).to_a }
        .to raise_error(CsvPipeline::ParseError, /blank header name/)
    end
  end
end
