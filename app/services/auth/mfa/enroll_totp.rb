# frozen_string_literal: true

module Auth
  module Mfa
    class EnrollTotp
      Result = Struct.new(:success?, :recovery_codes, :error, keyword_init: true)

      def self.call(user:, secret:, code:)
        new(user:, secret:, code:).call
      end

      def initialize(user:, secret:, code:)
        @user = user
        @secret = secret.to_s
        @code = code.to_s
      end

      def call
        timestamp = totp.verify(@code, drift_behind: 30, drift_ahead: 30)
        return Result.new(success?: false, error: :invalid_code) if timestamp.blank?

        first_factor = !@user.mfa_enabled?
        verified_at = Time.at(timestamp)
        recovery_codes = nil

        User.transaction do
          @user.update!(
            totp_secret: @secret,
            totp_enabled_at: Time.current,
            totp_last_verified_at: verified_at,
            totp_consumed_timestep: timestamp.to_i / 30,
            mfa_enabled_at: (@user.mfa_enabled_at || Time.current)
          )

          recovery_codes = GenerateRecoveryCodes.call(user: @user) if first_factor
        end

        Result.new(success?: true, recovery_codes:)
      end

      private

      def totp
        @totp ||= ROTP::TOTP.new(@secret, issuer: "Anella")
      end
    end
  end
end
