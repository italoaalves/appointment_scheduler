# frozen_string_literal: true

module Auth
  module Mfa
    class RemovePasskey
      Result = Struct.new(:success?, :error, keyword_init: true)

      def self.call(user:, passkey:)
        new(user:, passkey:).call
      end

      def initialize(user:, passkey:)
        @user = user
        @passkey = passkey
      end

      def call
        return Result.new(success?: false, error: :not_found) unless @passkey.user_id == @user.id

        remaining_factors = @user.user_passkeys.where.not(id: @passkey.id).exists? || @user.totp_enabled?
        return Result.new(success?: false, error: :last_factor_required) if !remaining_factors && @user.super_admin?

        User.transaction do
          @passkey.destroy!

          next if remaining_factors

          @user.user_recovery_codes.delete_all
          @user.update!(mfa_enabled_at: nil)
        end

        Result.new(success?: true)
      end
    end
  end
end
