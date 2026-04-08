# frozen_string_literal: true

require "openssl"

module Security
  class ActiveRecordEncryptionConfig
    REQUIRED_KEYS = %i[primary_key deterministic_key key_derivation_salt].freeze
    LOCAL_ENVIRONMENTS = %w[development test].freeze

    class << self
      def configure!
        ActiveRecord::Encryption.configure(**resolved_keys)
        ActiveRecord::Encryption.config.support_unencrypted_data = true
        ActiveRecord::Encryption.config.extend_queries = true

        ActiveRecord::Encryption::ExtendedDeterministicQueries.install_support
        ActiveRecord::Encryption::ExtendedDeterministicUniquenessValidator.install_support
      end

      private

      def resolved_keys
        explicit_keys.presence || fallback_keys
      end

      def explicit_keys
        REQUIRED_KEYS.each_with_object({}) do |key, values|
          value = fetch_value(key)
          values[key] = value if present_value?(value)
        end.tap do |values|
          next if values.empty?

          missing_keys = REQUIRED_KEYS - values.keys
          next if missing_keys.empty?

          raise ActiveRecord::Encryption::Errors::Configuration,
                "Missing Active Record encryption keys: #{missing_keys.join(', ')}"
        end
      end

      def fallback_keys
        return derived_fallback_keys if secret_key_base_fallback_allowed?

        raise ActiveRecord::Encryption::Errors::Configuration,
              "Missing Active Record encryption keys for #{Rails.env}"
      end

      def secret_key_base_fallback_allowed?
        # Rails sets SECRET_KEY_BASE_DUMMY during build-time asset precompilation.
        LOCAL_ENVIRONMENTS.include?(Rails.env) || ENV["SECRET_KEY_BASE_DUMMY"].present?
      end

      def derived_fallback_keys
        secret_key_base = Rails.application.secret_key_base

        raise ActiveRecord::Encryption::Errors::Configuration, "Missing secret_key_base" if secret_key_base.blank?

        {
          primary_key: derive_value(secret_key_base, "primary_key"),
          deterministic_key: derive_value(secret_key_base, "deterministic_key"),
          key_derivation_salt: derive_value(secret_key_base, "key_derivation_salt")
        }
      end

      def fetch_value(key)
        ENV["ACTIVE_RECORD_ENCRYPTION_#{key.to_s.upcase}"].presence ||
          Rails.application.credentials.dig(:active_record_encryption, key)
      end

      def present_value?(value)
        value.respond_to?(:any?) ? value.any?(&:present?) : value.present?
      end

      def derive_value(secret, purpose)
        OpenSSL::HMAC.hexdigest("SHA256", secret, "active-record-encryption/#{purpose}")
      end
    end
  end
end
