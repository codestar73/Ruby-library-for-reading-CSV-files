# frozen_string_literal: true

module CsvPipeline
  module Rules
    module RuleName
      module_function

      def for(klass)
        klass.name.split("::").last
      end
    end

    class NormalizeEmail
      def initialize(field = :email)
        @field = field.to_sym
      end

      def call(record)
        value = record[@field]
        return if value.nil?

        record[@field] = value.to_s.strip.downcase
      end
    end

    class DefaultValue
      def initialize(field, default_value)
        @field = field.to_sym
        @default_value = default_value
      end

      def call(record)
        return unless Blank.blank?(record[@field])

        record[@field] = @default_value
      end
    end

    class Presence
      def initialize(field, message: nil, code: :blank, locale: Messages.locale)
        @field = field.to_sym
        @message = message || Messages.t(:blank, locale: locale)
        @code = code
      end

      def call(record)
        return unless Blank.blank?(record[@field])

        record.add_error(
          @field,
          @message,
          code: @code,
          value: record[@field],
          rule: RuleName.for(self.class)
        )
      end
    end

    class Format
      def initialize(field, pattern, message: nil, code: :invalid_format, skip_blank: true, locale: Messages.locale)
        @field = field.to_sym
        @pattern = pattern
        @message = message || Messages.t(:invalid_format, locale: locale)
        @code = code
        @skip_blank = skip_blank
      end

      def call(record)
        value = record[@field]
        return if @skip_blank && Blank.blank?(value)
        return if value.to_s.match?(@pattern)

        record.add_error(
          @field,
          @message,
          code: @code,
          value: value,
          rule: RuleName.for(self.class)
        )
      end
    end

    class EmailFormat < Format
      def initialize(field = :email, pattern: Patterns::EMAIL, message: nil, locale: Messages.locale, **options)
        message ||= Messages.t(:invalid_email_format, locale: locale)
        super(field, pattern, message: message, code: :invalid_format, locale: locale, **options)
      end
    end

    class BlockRule
      def initialize(field, type, block)
        @field = field.to_sym
        @type = type
        @block = block
      end

      def call(record)
        value = record[@field]

        case @type
        when :transform
          record[@field] = RuleInvoker.call_field_rule(@block, value, record)
        when :validate
          message = RuleInvoker.call_field_rule(@block, value, record)
          return if message.nil? || message == true

          record.add_error(
            @field,
            message.to_s,
            code: :validation_error,
            value: value,
            rule: "BlockRule"
          )
        else
          raise ConfigurationError, "unknown block rule type: #{@type}"
        end
      end
    end
  end
end
