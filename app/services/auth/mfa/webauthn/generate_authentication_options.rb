# frozen_string_literal: true

module Auth
  module Mfa
    module Webauthn
      class GenerateAuthenticationOptions
        def self.call(user:, session:)
          new(user:, session:).call
        end

        def initialize(user:, session:)
          @user = user
          @session = session
        end

        def call
          options = WebAuthn::Credential.options_for_get(
            allow: @user.user_passkeys.pluck(:external_id),
            user_verification: "required"
          )

          Auth::PendingMfaSession.store_passkey_authentication_challenge(session: @session, challenge: options.challenge)
          options
        end
      end
    end
  end
end
