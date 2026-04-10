# frozen_string_literal: true

require "test_helper"

module Auth
  module Mfa
    class DisableTotpTest < ActiveSupport::TestCase
      test "disables the last totp factor for regular users" do
        user = users(:manager_two)
        user.update!(
          mfa_enabled_at: Time.current,
          totp_secret: ROTP::Base32.random,
          totp_enabled_at: Time.current,
          totp_last_verified_at: Time.current,
          totp_consumed_timestep: 123
        )
        GenerateRecoveryCodes.call(user:)

        result = DisableTotp.call(user:)

        assert result.success?
        assert_not user.reload.mfa_enabled?
        assert_not user.totp_enabled?
        assert_equal 0, user.user_recovery_codes.count
      end

      test "blocks super admins from disabling their last factor" do
        user = users(:admin)
        user.update!(
          mfa_enabled_at: Time.current,
          totp_secret: ROTP::Base32.random,
          totp_enabled_at: Time.current
        )

        result = DisableTotp.call(user:)

        assert_not result.success?
        assert_equal :last_factor_required, result.error
        assert user.reload.totp_enabled?
      end

      test "keeps mfa enabled when passkeys remain" do
        user = users(:manager_two)
        user.update!(
          mfa_enabled_at: Time.current,
          totp_secret: ROTP::Base32.random,
          totp_enabled_at: Time.current
        )
        user.user_passkeys.create!(
          external_id: "credential-4",
          public_key: "public-key",
          sign_count: 0,
          label: "YubiKey"
        )
        GenerateRecoveryCodes.call(user:)

        result = DisableTotp.call(user:)

        assert result.success?
        assert user.reload.mfa_enabled?
        assert_equal 1, user.user_passkeys.count
        assert_equal 10, user.user_recovery_codes.count
      end
    end
  end
end
