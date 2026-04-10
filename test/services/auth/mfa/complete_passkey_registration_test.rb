# frozen_string_literal: true

require "test_helper"

module Auth
  module Mfa
    class CompletePasskeyRegistrationTest < ActiveSupport::TestCase
      test "registers a passkey and recovery codes for the first factor" do
        user = users(:manager_two)
        session = {}
        options = Auth::Mfa::Webauthn::GenerateRegistrationOptions.call(user:, session:)
        credential = webauthn_fake_client.create(
          challenge: options.challenge,
          rp_id: WebAuthn.configuration.rp_id,
          user_verified: true
        )

        result = CompletePasskeyRegistration.call(
          user:,
          session:,
          credential:,
          label: "MacBook Pro"
        )

        assert result.success?
        assert_equal "MacBook Pro", result.passkey.label
        assert_equal 10, result.recovery_codes.length
        assert user.reload.mfa_enabled?
      end

      test "returns the registration error when the request is invalid" do
        user = users(:manager_two)
        session = {}
        Auth::Mfa::Webauthn::GenerateRegistrationOptions.call(user:, session:)

        result = CompletePasskeyRegistration.call(
          user:,
          session:,
          credential: {},
          label: ""
        )

        assert_not result.success?
        assert_equal :label_blank, result.error
      end

      test "does not regenerate recovery codes when mfa is already enabled" do
        user = users(:manager_two)
        user.update!(mfa_enabled_at: Time.current)
        Auth::Mfa::GenerateRecoveryCodes.call(user:)
        session = {}
        options = Auth::Mfa::Webauthn::GenerateRegistrationOptions.call(user:, session:)
        credential = webauthn_fake_client.create(
          challenge: options.challenge,
          rp_id: WebAuthn.configuration.rp_id,
          user_verified: true
        )

        result = CompletePasskeyRegistration.call(
          user:,
          session:,
          credential:,
          label: "YubiKey"
        )

        assert result.success?
        assert_nil result.recovery_codes
        assert_equal 10, user.user_recovery_codes.count
      end
    end
  end
end
