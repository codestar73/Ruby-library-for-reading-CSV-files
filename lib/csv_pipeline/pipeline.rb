# frozen_string_literal: true

require "stringio"

module CsvPipeline
  class Pipeline
    def self.build(&block)
      new.tap(&block)
    end

    def self.customer_import
      new([
        NormalizeEmail.new(:email),
        Presence.new(:email),
        Format.new(:email, EMAIL_PATTERN),
        DefaultValue.new(:name, "empty")
      ])
    end

    def self.from_yaml(source)
      YamlLoader.load(source)
    end

    def self.from_schema(**options, &block)
      Schema.build(**options, &block)
    end

    def initialize(rules = [], fail_fast: false)
      @rules = Array(rules).dup
      @fail_fast = fail_fast
      @rules.each { |rule| validate_rule!(rule) }
    end

    attr_reader :rules, :fail_fast

    def add(rule)
      validate_rule!(rule)
      @rules << rule
      self
    end

    def field(name, &block)
      FieldBuilder.new(self, name).instance_eval(&block)
      self
    end

    alias required field

    def optional(field, default:, &block)
      FieldBuilder.new(self, field).instance_eval(&block) if block
      add(Rules::DefaultValue.new(field, default))
      self
    end

    def transform(field, rule = nil, **options, &block)
      add(build_field_rule(field, rule, :transform, options, block))
    end

    def validate(field, rule = nil, **options, &block)
      add(build_field_rule(field, rule, :validate, options, block))
    end

    def when(predicate)
      builder = ConditionalBuilder.new(self, predicate)
      yield builder if block_given?
      self
    end

    def each_processed_record(source, reader: CsvReader.new, &block)
      return enum_for(:each_processed_record, source, reader: reader) unless block_given?

      each_source_record(source, reader) { |record| yield run(record) }
    end

    def process(source, reader: CsvReader.new, materialize: true)
      if materialize
        ProcessingResult.new(each_processed_record(source, reader: reader).to_a)
      else
        LazyProcessingResult.new(source, self, reader: reader)
      end
    end

    def run(record, fresh: false)
      record = coerce_record(record) unless record.is_a?(Record)
      record = record.fresh_copy if fresh
      @rules.each do |rule|
        errors_before = record.errors.size
        rule.call(record)
        break if @fail_fast && record.errors.size > errors_before
      end
      record
    end

    def merge(other)
      other.rules.each { |rule| add(rule) }
      self
    end

    def +(other)
      self.class.new(@rules + other.rules, fail_fast: @fail_fast || other.fail_fast)
    end

    private

    def each_source_record(source, reader)
      case source
      when String, IO, StringIO
        reader.each_record(source) { |record| yield record }
      when Enumerable
        source.each_with_index do |item, index|
          yield coerce_record(item, row: row_number_for(item, index))
        end
      else
        raise ArgumentError, "unsupported source type: #{source.class}"
      end
    end

    def row_number_for(item, index)
      item.is_a?(Record) && item.row ? item.row : index + 1
    end

    def coerce_record(item, row: item.is_a?(Record) ? item.row : nil)
      return item if item.is_a?(Record)

      Record.new(item, row: row)
    end

    def validate_rule!(rule)
      return if rule.respond_to?(:call)

      raise ConfigurationError, "rule must respond to #call(record), got #{rule.class}"
    end

    def build_field_rule(field, rule, type, options, block)
      if block
        Rules::BlockRule.new(field, type, block)
      elsif rule.is_a?(Class)
        instantiate_rule(rule, field, options)
      elsif rule.respond_to?(:call)
        Rules::BlockRule.new(field, type, rule)
      else
        raise ConfigurationError, "expected a rule class, callable, or block for field #{field.inspect}"
      end
    end

    def instantiate_rule(rule_class, field, options)
      if rule_class <= Rules::DefaultValue
        default = options.fetch(:default) { raise ConfigurationError, "DefaultValue requires a default value" }
        rule_class.new(field, default)
      elsif rule_class <= Rules::EmailFormat
        rule_class.new(field, **options)
      elsif rule_class <= Rules::Format
        pattern = options.fetch(:pattern) { raise ConfigurationError, "Format requires a pattern" }
        rule_class.new(field, pattern, **options.except(:pattern))
      else
        rule_class.new(field, **options)
      end
    end
  end
end
