# frozen_string_literal: true

require "yaml"

module CsvPipeline
  class YamlLoader
    RULE_TYPES = {
      "normalize_email" => Rules::NormalizeEmail,
      "default_value" => Rules::DefaultValue,
      "presence" => Rules::Presence,
      "format" => Rules::Format,
      "email_format" => Rules::EmailFormat
    }.freeze

    class << self
      def load(source)
        config = parse(source)
        build_pipeline(config)
      end

      private

      def parse(source)
        case source
        when Hash
          source
        when String
          if File.exist?(source)
            YAML.safe_load(File.read(source), permitted_classes: [Regexp, Symbol]) || {}
          else
            YAML.safe_load(source, permitted_classes: [Regexp, Symbol]) || {}
          end
        else
          raise ArgumentError, "unsupported YAML source: #{source.class}"
        end
      end

      def build_pipeline(config)
        locale = (config["locale"] || Messages.locale).to_sym
        Messages.locale = locale

        rules = Array(config["rules"]).map { |entry| build_rule(entry, locale: locale) }
        Pipeline.new(rules, fail_fast: config.fetch("fail_fast", false))
      end

      def build_rule(entry, locale:)
        entry = entry.transform_keys(&:to_s)
        type = entry.fetch("type")
        field = entry.fetch("field").to_sym

        case type
        when "normalize_email"
          Rules::NormalizeEmail.new(field)
        when "default_value"
          Rules::DefaultValue.new(field, entry.fetch("default"))
        when "presence"
          Rules::Presence.new(
            field,
            message: entry["message"] || Messages.t(:blank, locale: locale)
          )
        when "format"
          Rules::Format.new(
            field,
            Regexp.new(entry.fetch("pattern")),
            message: entry["message"] || Messages.t(:invalid_format, locale: locale),
            skip_blank: entry.fetch("skip_blank", true)
          )
        when "email_format"
          Rules::EmailFormat.new(
            field,
            message: entry["message"] || Messages.t(:invalid_email_format, locale: locale)
          )
        when "conditional"
          predicate = build_predicate(entry.fetch("if"))
          build_rule({ "type" => entry.fetch("then"), "field" => field.to_s }, locale: locale).then do |rule|
            Rules::Conditional.new(predicate, rule)
          end
        else
          raise ConfigurationError, "unknown YAML rule type: #{type}"
        end
      end

      def build_predicate(condition)
        case condition
        when Hash
          field = condition.fetch("field").to_s
          value = condition["equals"]
          ->(record) { record[field] == value }
        when String
          field, expected = condition.split("=", 2)
          ->(record) { record[field.strip].to_s == expected.strip }
        else
          raise ConfigurationError, "unsupported conditional predicate: #{condition.inspect}"
        end
      end
    end
  end
end
