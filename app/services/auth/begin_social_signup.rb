# frozen_string_literal: true

module Auth
  class BeginSocialSignup
    SESSION_KEY = "auth.pending_social_signup"
    TTL = 30.minutes

    def self.call(session:, provider:, uid:, email:, email_verified:, name:)
      session[SESSION_KEY] = {
        "provider" => provider.to_s,
        "uid" => uid.to_s,
        "email" => email.presence,
        "email_verified" => boolean(email_verified),
        "name" => name.presence,
        "issued_at" => Time.current.to_i
      }
    end

    def self.fetch(session:)
      payload = session[SESSION_KEY]
      return if payload.blank?

      normalized = payload.deep_symbolize_keys
      return clear(session:) if expired?(normalized[:issued_at])

      normalized[:email_verified] = boolean(normalized[:email_verified])
      normalized
    rescue StandardError
      clear(session:)
    end

    def self.clear(session:)
      session.delete(SESSION_KEY)
      nil
    end

    def self.trusted_verified_email?(payload)
      return false if payload.blank? || payload[:email].blank?

      payload[:provider].to_s == "apple" || boolean(payload[:email_verified])
    end

    def self.boolean(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end
    private_class_method :boolean

    def self.expired?(issued_at)
      issued_at.to_i < TTL.ago.to_i
    end
    private_class_method :expired?
  end
end
