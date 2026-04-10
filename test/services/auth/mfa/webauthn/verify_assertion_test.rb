# frozen_string_literal: true

require "test_helper"

module Auth
  module Mfa
    module Webauthn
      class VerifyAssertionTest < ActiveSupport::TestCase
        test "verifies a passkey assertion and updates usage fields" do
          user = users(:admin)
          register_session = {}
          registration_options = GenerateRegistrationOptions.call(user:, session: register_session)
          fake_client = webauthn_fake_client
          registration_credential = fake_client.create(
            challenge: registration_options.challenge,
            rp_id: WebAuthn.configuration.rp_id,
            user_verified: true
          )

          register_result = RegisterPasskey.call(
            user:,
            session: register_session,
            credential: registration_credential,
            label: "iPhone"
          )
          assert register_result.success?

          auth_session = {}
          request_options = GenerateAuthenticationOptions.call(user:, session: auth_session)
          assertion = fake_client.get(
            challenge: request_options.challenge,
            rp_id: WebAuthn.configuration.rp_id,
            user_verified: true,
            allow_credentials: user.user_passkeys.pluck(:external_id)
          )

          result = VerifyAssertion.call(user:, session: auth_session, credential: assertion)

          assert result.success?
          assert_not_nil result.passkey.reload.last_used_at
          assert_nil Auth::PendingMfaSession.passkey_authentication_challenge(session: auth_session)
        end
      end
    end
  end
end
