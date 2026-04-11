# frozen_string_literal: true

class LocaleResolver
  class << self
    def normalize(locale)
      candidate = locale.to_s.strip
      return if candidate.blank?

      normalized = candidate.tr("_", "-")
      available_locales.find { |value| value.casecmp?(normalized) } ||
        available_locales.find { |value| value.split("-").first.casecmp?(normalized.split("-").first) }
    end

    def from_accept_language(header)
      header.to_s.split(",").filter_map.with_index do |entry, index|
        language_tag, *parameters = entry.strip.split(";")
        locale = normalize(language_tag)
        next unless locale

        quality = parameters
          .map(&:strip)
          .find { |parameter| parameter.start_with?("q=") }
          &.split("=", 2)
          &.last
          &.to_f || 1.0
        next if quality <= 0

        [ locale, quality, -index ]
      end.max_by { |_locale, quality, order| [ quality, order ] }&.first
    end

    def recipient(recipient, fallback_space: nil)
      case recipient
      when User
        normalize(recipient.user_preference&.locale) ||
          space(recipient.space || fallback_space)
      when Customer
        normalize(recipient.user&.user_preference&.locale) ||
          normalize(recipient.locale) ||
          space(recipient.space || fallback_space)
      else
        space(fallback_space)
      end || I18n.default_locale.to_s
    end

    def space(space)
      normalize(space&.owner&.user_preference&.locale) || I18n.default_locale.to_s
    end

    private

    def available_locales
      I18n.available_locales.map(&:to_s)
    end
  end
end
