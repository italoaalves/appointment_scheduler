# frozen_string_literal: true

module Onboarding
  class SlugGenerator
    MAX_LENGTH = 40
    CONFLICT_RETRIES = 3

    def self.call(name)
      new.call(name)
    end

    def call(name)
      base = sanitize(name.to_s)
      return SecureRandom.hex(8) if base.blank?

      (0..CONFLICT_RETRIES).each do |i|
        candidate = i.zero? ? base : "#{base}-#{SecureRandom.hex(1)}"
        return candidate unless PersonalizedSchedulingLink.exists?(slug: candidate)
      end

      SecureRandom.hex(8)
    end

    private

    def sanitize(str)
      str = ActiveSupport::Inflector.transliterate(str)
      str = str.downcase
      str = str.gsub(/[^a-z0-9]+/, "-")
      str = str.gsub(/-+/, "-")
      str = str.sub(/\A-+/, "").sub(/-+\z/, "")
      truncate_at_boundary(str, MAX_LENGTH)
    end

    def truncate_at_boundary(str, max)
      return str if str.length <= max

      truncated = str[0, max]
      last_hyphen = truncated.rindex("-")
      last_hyphen && last_hyphen > max / 2 ? truncated[0, last_hyphen] : truncated
    end
  end
end
