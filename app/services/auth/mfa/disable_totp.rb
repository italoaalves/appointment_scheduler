# frozen_string_literal: true

module Auth
  module Mfa
    class DisableTotp
      Result = Struct.new(:success?, :error, keyword_init: true)

      def self.call(user:)
        new(user:).call
      end

      def initialize(user:)
        @user = user
      end

      def call
        return Result.new(success?: false, error: :not_enabled) unless @user.totp_enabled?

        remaining_factors = @user.user_passkeys.exists?
        return Result.new(success?: false, error: :last_factor_required) if !remaining_factors && @user.super_admin?

        User.transaction do
          @user.update!(
            totp_secret: nil,
            totp_enabled_at: nil,
            totp_last_verified_at: nil,
            totp_consumed_timestep: nil,
            mfa_enabled_at: (remaining_factors ? @user.mfa_enabled_at : nil)
          )

          @user.user_recovery_codes.delete_all unless remaining_factors
        end

        Result.new(success?: true)
      end
    end
  end
end
