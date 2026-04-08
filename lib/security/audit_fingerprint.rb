# frozen_string_literal: true

require "openssl"

module Security
  class AuditFingerprint
    PURPOSE_NORMALIZERS = {
      email: ->(value) { value.to_s.unicode_normalize(:nfkc).strip.downcase },
      name: ->(value) { value.to_s.unicode_normalize(:nfkc).squish.downcase },
      phone_number: ->(value) { value.to_s.gsub(/\D/, "") },
      cpf_cnpj: ->(value) { value.to_s.gsub(/\D/, "") }
    }.freeze

    def self.call(value, purpose:)
      normalized = normalize(value, purpose:)
      return if normalized.blank?

      OpenSSL::HMAC.hexdigest("SHA256", secret, "#{purpose}:#{normalized}")
    end

    def self.normalize(value, purpose:)
      PURPOSE_NORMALIZERS.fetch(purpose.to_sym).call(value)
    end

    def self.secret
      "#{Rails.application.secret_key_base}:audit-fingerprint"
    end
    private_class_method :secret
  end
end
