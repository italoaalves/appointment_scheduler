# frozen_string_literal: true

module Auth
  module Mfa
    module Webauthn
      class GenerateRegistrationOptions
        def self.call(user:, session:)
          new(user:, session:).call
        end

        def initialize(user:, session:)
          @user = user
          @session = session
        end

        def call
          @user.ensure_webauthn_id!

          options = WebAuthn::Credential.options_for_create(
            user: {
              id: @user.webauthn_id,
              name: @user.email,
              display_name: @user.name.presence || @user.email
            },
            exclude: @user.user_passkeys.pluck(:external_id),
            attestation: "none",
            authenticator_selection: {
              user_verification: "required"
            }
          )

          Auth::PendingMfaSession.store_passkey_registration_challenge(session: @session, challenge: options.challenge)
          options
        end
      end
    end
  end
end
