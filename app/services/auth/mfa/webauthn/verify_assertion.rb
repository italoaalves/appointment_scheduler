# frozen_string_literal: true

module Auth
  module Mfa
    module Webauthn
      class VerifyAssertion
        Result = Struct.new(:success?, :passkey, :error, keyword_init: true)

        def self.call(user:, session:, credential:)
          new(user:, session:, credential:).call
        end

        def initialize(user:, session:, credential:)
          @user = user
          @session = session
          @credential = credential
        end

        def call
          challenge = Auth::PendingMfaSession.passkey_authentication_challenge(session: @session)
          return Result.new(success?: false, error: :expired) if challenge.blank?

          webauthn_credential = WebAuthn::Credential.from_get(@credential)
          passkey = @user.user_passkeys.find_by(external_id: webauthn_credential.id)
          return Result.new(success?: false, error: :authentication_failed) if passkey.blank?

          webauthn_credential.verify(
            challenge,
            public_key: passkey.public_key,
            sign_count: passkey.sign_count,
            user_verification: true
          )

          passkey.update!(
            sign_count: webauthn_credential.sign_count,
            last_used_at: Time.current,
            backup_eligible: webauthn_credential.backup_eligible?,
            backup_state: webauthn_credential.backed_up?
          )

          Auth::PendingMfaSession.clear_passkey_authentication_challenge(session: @session)

          Result.new(success?: true, passkey:)
        rescue WebAuthn::Error
          Result.new(success?: false, error: :authentication_failed)
        end
      end
    end
  end
end
