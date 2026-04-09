# frozen_string_literal: true

module Auth
  module Mfa
    module Webauthn
      class RegisterPasskey
        Result = Struct.new(:success?, :passkey, :error, keyword_init: true)

        def self.call(user:, session:, credential:, label:)
          new(user:, session:, credential:, label:).call
        end

        def initialize(user:, session:, credential:, label:)
          @user = user
          @session = session
          @credential = credential
          @label = label.to_s.strip
        end

        def call
          return Result.new(success?: false, error: :label_blank) if @label.blank?

          challenge = Auth::PendingMfaSession.passkey_registration_challenge(session: @session)
          return Result.new(success?: false, error: :expired) if challenge.blank?

          webauthn_credential = WebAuthn::Credential.from_create(@credential)
          webauthn_credential.verify(challenge, user_verification: true)

          passkey = @user.user_passkeys.create!(
            external_id: webauthn_credential.id,
            public_key: webauthn_credential.public_key,
            sign_count: webauthn_credential.sign_count,
            label: @label,
            transports: Array(webauthn_credential.response.transports).compact,
            platform_authenticator: webauthn_credential.authenticator_attachment == "platform",
            backup_eligible: webauthn_credential.backup_eligible?,
            backup_state: webauthn_credential.backed_up?
          )

          Auth::PendingMfaSession.clear_passkey_registration_challenge(session: @session)

          Result.new(success?: true, passkey:)
        rescue WebAuthn::Error, ActiveRecord::RecordInvalid
          Result.new(success?: false, error: :registration_failed)
        end
      end
    end
  end
end
