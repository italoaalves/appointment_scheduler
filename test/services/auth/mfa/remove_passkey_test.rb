# frozen_string_literal: true

require "test_helper"

module Auth
  module Mfa
    class RemovePasskeyTest < ActiveSupport::TestCase
      test "removes the last passkey and disables mfa for regular users" do
        user = users(:manager_two)
        user.update!(mfa_enabled_at: Time.current)
        GenerateRecoveryCodes.call(user:)
        passkey = user.user_passkeys.create!(
          external_id: "credential-1",
          public_key: "public-key",
          sign_count: 0,
          label: "MacBook Pro"
        )

        result = RemovePasskey.call(user:, passkey:)

        assert result.success?
        assert_not user.reload.mfa_enabled?
        assert_equal 0, user.user_passkeys.count
        assert_equal 0, user.user_recovery_codes.count
      end

      test "blocks super admins from deleting their last factor" do
        user = users(:admin)
        user.update!(mfa_enabled_at: Time.current)
        passkey = user.user_passkeys.create!(
          external_id: "credential-2",
          public_key: "public-key",
          sign_count: 0,
          label: "Security key"
        )

        result = RemovePasskey.call(user:, passkey:)

        assert_not result.success?
        assert_equal :last_factor_required, result.error
        assert_equal 1, user.user_passkeys.count
      end

      test "keeps mfa enabled when another factor remains" do
        user = users(:manager_two)
        user.update!(
          mfa_enabled_at: Time.current,
          totp_secret: ROTP::Base32.random,
          totp_enabled_at: Time.current
        )
        GenerateRecoveryCodes.call(user:)
        passkey = user.user_passkeys.create!(
          external_id: "credential-3",
          public_key: "public-key",
          sign_count: 0,
          label: "iPhone"
        )

        result = RemovePasskey.call(user:, passkey:)

        assert result.success?
        assert user.reload.mfa_enabled?
        assert user.totp_enabled?
        assert_equal 10, user.user_recovery_codes.count
      end
    end
  end
end
