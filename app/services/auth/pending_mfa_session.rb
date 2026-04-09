# frozen_string_literal: true

module Auth
  class PendingMfaSession
    PENDING_KEY = "auth.pending_mfa"
    VERIFIED_AT_KEY = "auth.mfa_verified_at"
    VERIFIED_USER_ID_KEY = "auth.mfa_verified_user_id"
    PENDING_TOTP_SECRET_KEY = "auth.pending_totp_secret"
    RECOVERY_CODES_KEY = "auth.pending_recovery_codes"
    EXPIRY = 10.minutes
    MAX_ATTEMPTS = 5

    def self.start(session:, user:, primary_method:, remember_me:, return_to: nil)
      clear(session:)
      clear_verified(session:)

      session[PENDING_KEY] = {
        "user_id" => user.id,
        "primary_method" => primary_method.to_s,
        "remember_me" => ActiveModel::Type::Boolean.new.cast(remember_me),
        "return_to" => return_to.presence,
        "started_at" => Time.current.to_i,
        "attempts" => 0
      }
    end

    def self.fetch(session:)
      payload = session[PENDING_KEY]
      return if payload.blank?

      normalized = payload.deep_symbolize_keys
      return clear(session:) if expired?(normalized[:started_at])

      normalized[:remember_me] = ActiveModel::Type::Boolean.new.cast(normalized[:remember_me])
      normalized
    rescue StandardError
      clear(session:)
    end

    def self.pending_user(session:)
      pending = fetch(session:)
      return if pending.blank?

      User.find_by(id: pending[:user_id])
    end

    def self.increment_attempts!(session:)
      pending = fetch(session:)
      return 0 if pending.blank?

      attempts = pending[:attempts].to_i + 1
      session[PENDING_KEY]["attempts"] = attempts
      attempts
    end

    def self.attempt_limit_reached?(session:)
      fetch(session:).to_h[:attempts].to_i >= MAX_ATTEMPTS
    end

    def self.mark_verified!(session:, user:)
      clear(session:)
      session[VERIFIED_USER_ID_KEY] = user.id
      session[VERIFIED_AT_KEY] = Time.current.to_i
    end

    def self.verified?(session:, user:)
      session[VERIFIED_USER_ID_KEY].to_i == user.id && session[VERIFIED_AT_KEY].present?
    end

    def self.clear_verified(session:)
      session.delete(VERIFIED_USER_ID_KEY)
      session.delete(VERIFIED_AT_KEY)
    end

    def self.store_pending_totp_secret(session:, secret:)
      session[PENDING_TOTP_SECRET_KEY] = secret
    end

    def self.pending_totp_secret(session:)
      session[PENDING_TOTP_SECRET_KEY]
    end

    def self.clear_pending_totp_secret(session:)
      session.delete(PENDING_TOTP_SECRET_KEY)
    end

    def self.store_recovery_codes(session:, codes:)
      session[RECOVERY_CODES_KEY] = Array(codes)
    end

    def self.recovery_codes(session:)
      Array(session[RECOVERY_CODES_KEY]).presence
    end

    def self.clear_recovery_codes(session:)
      session.delete(RECOVERY_CODES_KEY)
    end

    def self.clear(session:)
      clear_pending_totp_secret(session:)
      clear_recovery_codes(session:)
      session.delete(PENDING_KEY)
      nil
    end

    def self.expired?(started_at)
      started_at.to_i < EXPIRY.ago.to_i
    end
    private_class_method :expired?
  end
end
