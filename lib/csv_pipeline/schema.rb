# frozen_string_literal: true

module CsvPipeline
  class Schema
    def self.build(**options, &block)
      new(&block).to_pipeline(**options)
    end

    def initialize(&block)
      @steps = []
      instance_eval(&block) if block
    end

    def required(*fields)
      fields.each { |field| @steps << [:required, field.to_sym] }
    end

    def optional(field, default:)
      @steps << [:optional, field.to_sym, default]
    end

    def format(field, pattern, message: nil)
      @steps << [:format, field.to_sym, pattern, message]
    end

    def email_format(field = :email, message: nil)
      @steps << [:email_format, field.to_sym, message]
    end

    def normalize_email(field = :email)
      @steps << [:normalize_email, field.to_sym]
    end

    def cross_field(rule)
      @steps << [:cross_field, rule]
    end

    def to_pipeline(fail_fast: false, locale: Messages.locale)
      Pipeline.new(build_rules(locale: locale), fail_fast: fail_fast)
    end

    def build_rules(locale: Messages.locale)
      @steps.flat_map { |step| rule_for(step, locale: locale) }
    end

    private

    def rule_for(step, locale:)
      case step
      in [:required, field]
        [Rules::Presence.new(field, message: Messages.t(:blank, locale: locale))]
      in [:optional, field, default]
        [Rules::DefaultValue.new(field, default)]
      in [:format, field, pattern, message]
        msg = message || Messages.t(:invalid_format, locale: locale)
        [Rules::Format.new(field, pattern, message: msg)]
      in [:email_format, field, message]
        msg = message || Messages.t(:invalid_email_format, locale: locale)
        [Rules::EmailFormat.new(field, message: msg)]
      in [:normalize_email, field]
        [Rules::NormalizeEmail.new(field)]
      in [:cross_field, rule]
        [rule]
      else
        raise ConfigurationError, "unknown schema step: #{step.inspect}"
      end
    end
  end
end
