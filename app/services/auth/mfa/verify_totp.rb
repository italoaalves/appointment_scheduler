# frozen_string_literal: true

module Auth
  module Mfa
    class VerifyTotp
      Result = Struct.new(:success?, :error, :verified_at, :consumed_timestep, keyword_init: true)

      def self.call(user:, code:)
        new(user:, code:).call
      end

      def initialize(user:, code:)
        @user = user
        @code = code.to_s.delete(" ")
      end

      def call
        return Result.new(success?: false, error: :not_enabled) if @user.totp_secret.blank?

        timestamp = totp.verify(@code, **verification_options)
        if timestamp.present?
          consumed_timestep = timestep_for(timestamp)
          @user.update!(
            totp_last_verified_at: Time.at(timestamp),
            totp_consumed_timestep: consumed_timestep
          )

          return Result.new(
            success?: true,
            verified_at: Time.at(timestamp),
            consumed_timestep:
          )
        end

        replayed_timestamp = totp.verify(@code, drift_behind: 30, drift_ahead: 30)
        if replayed_timestamp.present? && timestep_for(replayed_timestamp) <= @user.totp_consumed_timestep.to_i
          return Result.new(success?: false, error: :replayed_code)
        end

        Result.new(success?: false, error: :invalid_code)
      end

      private

      def totp
        @totp ||= ROTP::TOTP.new(@user.totp_secret, issuer: AppBrand.authenticator_name)
      end

      def verification_options
        options = { drift_behind: 30, drift_ahead: 30 }
        return options if @user.totp_consumed_timestep.blank?

        options[:after] = @user.totp_consumed_timestep * 30
        options
      end

      def timestep_for(timestamp)
        (timestamp.to_i / 30)
      end
    end
  end
end
