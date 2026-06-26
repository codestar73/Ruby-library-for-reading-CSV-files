# frozen_string_literal: true

module CsvPipeline
  module Messages
    TRANSLATIONS = {
      en: {
        blank: "must be present",
        invalid_format: "has an invalid format",
        invalid_email_format: "has an invalid email format"
      },
      es: {
        blank: "debe estar presente",
        invalid_format: "tiene un formato inválido",
        invalid_email_format: "tiene un formato de email inválido"
      }
    }.freeze

    @locale = :en
    @custom = {}

    module_function

    def locale
      @locale
    end

    def locale=(locale)
      @locale = locale.to_sym
    end

    def add(locale, key, message)
      @custom[locale.to_sym] ||= {}
      @custom[locale.to_sym][key.to_sym] = message
    end

    def reset!
      @locale = :en
      @custom = {}
    end

    def t(key, locale: @locale, **)
      key = key.to_sym
      locale = locale.to_sym
      @custom.dig(locale, key) ||
        TRANSLATIONS.dig(locale, key) ||
        TRANSLATIONS.dig(:en, key) ||
        key.to_s
    end
  end
end
