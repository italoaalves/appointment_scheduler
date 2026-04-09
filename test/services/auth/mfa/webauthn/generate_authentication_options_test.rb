# frozen_string_literal: true

require "test_helper"

module Auth
  module Mfa
    module Webauthn
      class GenerateAuthenticationOptionsTest < ActiveSupport::TestCase
        test "generates options and stores an authentication challenge" do
          user = users(:admin)
          create_registered_passkey_for(user)
          session = {}

          options = GenerateAuthenticationOptions.call(user:, session:)

          assert options.challenge.present?
          assert_equal options.challenge, Auth::PendingMfaSession.passkey_authentication_challenge(session:)
          assert_equal 1, options.allow_credentials.length
        end

        private

        def create_registered_passkey_for(user)
          session = {}
          options = GenerateRegistrationOptions.call(user:, session:)
          credential = webauthn_fake_client.create(
            challenge: options.challenge,
            rp_id: WebAuthn.configuration.rp_id,
            user_verified: true
          )

          RegisterPasskey.call(user:, session:, credential:, label: "Primary passkey")
        end
      end
    end
  end
end
