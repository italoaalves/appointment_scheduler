# frozen_string_literal: true

require "test_helper"

module Auth
  module Mfa
    module Webauthn
      class RegisterPasskeyTest < ActiveSupport::TestCase
        test "registers a verified passkey for the user" do
          user = users(:admin)
          session = {}
          options = GenerateRegistrationOptions.call(user:, session:)
          credential = webauthn_fake_client.create(
            challenge: options.challenge,
            rp_id: WebAuthn.configuration.rp_id,
            user_verified: true
          )

          result = RegisterPasskey.call(
            user:,
            session:,
            credential:,
            label: "MacBook Pro"
          )

          assert result.success?
          assert_equal "MacBook Pro", result.passkey.label
          assert_equal 1, user.user_passkeys.count
          assert_nil Auth::PendingMfaSession.passkey_registration_challenge(session:)
        end

        test "requires a label" do
          user = users(:admin)
          session = {}
          options = GenerateRegistrationOptions.call(user:, session:)
          credential = webauthn_fake_client.create(
            challenge: options.challenge,
            rp_id: WebAuthn.configuration.rp_id,
            user_verified: true
          )

          result = RegisterPasskey.call(user:, session:, credential:, label: "")

          assert_not result.success?
          assert_equal :label_blank, result.error
        end
      end
    end
  end
end
