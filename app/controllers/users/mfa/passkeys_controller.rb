# frozen_string_literal: true

module Users
  module Mfa
    class PasskeysController < ApplicationController
      include Devise::Controllers::Rememberable

      before_action :set_pending_mfa_user

      def registration_options
        options = Auth::Mfa::Webauthn::GenerateRegistrationOptions.call(user: @mfa_user, session: session)
        render json: options
      end

      def create
        result = Auth::Mfa::Webauthn::RegisterPasskey.call(
          user: @mfa_user,
          session: session,
          credential: credential_payload,
          label: passkey_label
        )

        unless result.success?
          return render json: { error: error_message_for(result.error) }, status: error_status_for(result.error)
        end

        @mfa_user.update!(mfa_enabled_at: (@mfa_user.mfa_enabled_at || Time.current))
        recovery_codes = Auth::Mfa::GenerateRecoveryCodes.call(user: @mfa_user)
        Auth::PendingMfaSession.store_recovery_codes(session:, codes: recovery_codes)

        AuditLogs::EventLogger.call(
          event_type: "auth.mfa_passkey_registered",
          actor: @mfa_user,
          subject: @mfa_user,
          auditable: result.passkey,
          request: request,
          metadata: audit_context_metadata.merge(label: result.passkey.label)
        )

        render json: { redirect_url: user_mfa_recovery_codes_path }
      end

      def authentication_options
        return render json: { error: error_message_for(:passkeys_unavailable) }, status: :unprocessable_entity unless @mfa_user.passkeys_enabled?

        options = Auth::Mfa::Webauthn::GenerateAuthenticationOptions.call(user: @mfa_user, session: session)
        render json: options
      end

      def authenticate
        result = Auth::Mfa::Webauthn::VerifyAssertion.call(
          user: @mfa_user,
          session: session,
          credential: credential_payload
        )

        unless result.success?
          log_challenge_failure(result.error)
          attempts = Auth::PendingMfaSession.increment_attempts!(session:)

          if attempts >= Auth::PendingMfaSession::MAX_ATTEMPTS
            Auth::PendingMfaSession.clear(session:)
            return render json: { redirect_url: new_user_session_path, error: t("mfa.challenge.expired") }, status: :unprocessable_entity
          end

          return render json: { error: error_message_for(result.error) }, status: error_status_for(result.error)
        end

        @mfa_user.update!(last_mfa_at: Time.current)
        sign_in(:user, @mfa_user)
        Auth::PendingMfaSession.mark_verified!(session:, user: @mfa_user)
        remember_me(@mfa_user) if @pending_mfa[:remember_me]

        log_challenge_success
        render json: { redirect_url: (@pending_mfa[:return_to].presence || after_sign_in_path_for(@mfa_user)) }
      end

      private

      def set_pending_mfa_user
        @pending_mfa = Auth::PendingMfaSession.fetch(session:)
        @mfa_user = Auth::PendingMfaSession.pending_user(session:)
        return if @pending_mfa.present? && @mfa_user.present?

        render json: { redirect_url: new_user_session_path, error: t("mfa.challenge.expired") }, status: :unprocessable_entity
      end

      def credential_payload
        payload = passkey_payload[:public_key_credential]
        raise ActionController::ParameterMissing, :public_key_credential if payload.blank?

        return payload.permit!.to_h if payload.is_a?(ActionController::Parameters)

        ActionController::Parameters.new(payload).permit!.to_h
      end

      def passkey_label
        passkey_payload[:label].presence
      end

      def passkey_payload
        payload = params[:passkey].presence || params
        payload.is_a?(ActionController::Parameters) ? payload : ActionController::Parameters.new(payload)
      end

      def error_message_for(error)
        return t("mfa.challenge.expired") if error == :expired

        scope =
          if %i[label_blank registration_failed passkeys_unavailable].include?(error)
            "mfa.passkeys.errors"
          else
            "mfa.challenge.errors"
          end

        t("#{scope}.#{error}")
      end

      def error_status_for(error)
        error == :expired ? :unprocessable_entity : :unprocessable_entity
      end

      def log_challenge_success
        AuditLogs::EventLogger.call(
          event_type: "auth.mfa_challenge_succeeded",
          actor: @mfa_user,
          subject: @mfa_user,
          request: request,
          metadata: audit_context_metadata.merge(factor: "passkey")
        )
      end

      def log_challenge_failure(error)
        AuditLogs::EventLogger.call(
          event_type: "auth.mfa_challenge_failed",
          subject: @mfa_user,
          request: request,
          metadata: audit_context_metadata.merge(error: error.to_s, factor: "passkey")
        )
      end
    end
  end
end
