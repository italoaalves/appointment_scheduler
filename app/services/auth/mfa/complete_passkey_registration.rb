# frozen_string_literal: true

module Auth
  module Mfa
    class CompletePasskeyRegistration
      Result = Struct.new(:success?, :passkey, :recovery_codes, :error, keyword_init: true)

      def self.call(user:, session:, credential:, label:)
        new(user:, session:, credential:, label:).call
      end

      def initialize(user:, session:, credential:, label:)
        @user = user
        @session = session
        @credential = credential
        @label = label
      end

      def call
        first_factor = !@user.mfa_enabled?
        registration = nil
        recovery_codes = nil

        User.transaction do
          registration = Webauthn::RegisterPasskey.call(
            user: @user,
            session: @session,
            credential: @credential,
            label: @label
          )

          raise ActiveRecord::Rollback unless registration.success?

          if first_factor
            @user.update!(mfa_enabled_at: (@user.mfa_enabled_at || Time.current))
            recovery_codes = GenerateRecoveryCodes.call(user: @user)
          end
        end

        return Result.new(success?: false, error: registration&.error || :registration_failed) unless registration&.success?

        Result.new(success?: true, passkey: registration.passkey, recovery_codes:)
      end
    end
  end
end
