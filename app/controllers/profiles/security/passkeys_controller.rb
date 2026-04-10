# frozen_string_literal: true

module Profiles
  module Security
    class PasskeysController < BaseController
      before_action :set_passkey, only: :destroy

      def registration_options
        options = Auth::Mfa::Webauthn::GenerateRegistrationOptions.call(user: @user, session: session)
        render json: options
      end

      def create
        result = Auth::Mfa::CompletePasskeyRegistration.call(
          user: @user,
          session: session,
          credential: credential_payload,
          label: passkey_label
        )

        unless result.success?
          return render json: { error: error_message_for(result.error) }, status: :unprocessable_entity
        end

        AuditLogs::EventLogger.call(
          event_type: "auth.mfa_passkey_registered",
          actor: audit_actor,
          space: current_tenant,
          subject: @user,
          auditable: result.passkey,
          request: request,
          impersonated: impersonating?,
          metadata: audit_context_metadata.merge(source: "profile_security", label: result.passkey.label)
        )

        redirect_url =
          if result.recovery_codes.present?
            Auth::RecoveryCodesDisplaySession.store(session:, user: @user, codes: result.recovery_codes)
            profile_security_recovery_codes_path
          else
            flash[:notice] = t("profiles.security.passkeys.created")
            profile_security_path
          end

        render json: { redirect_url: redirect_url }
      end

      def destroy
        result = Auth::Mfa::RemovePasskey.call(user: @user, passkey: @passkey)

        unless result.success?
          return redirect_to profile_security_path, alert: t("profiles.security.errors.#{result.error}")
        end

        AuditLogs::EventLogger.call(
          event_type: "auth.mfa_passkey_deleted",
          actor: audit_actor,
          space: current_tenant,
          subject: @user,
          auditable: @passkey,
          request: request,
          impersonated: impersonating?,
          metadata: audit_context_metadata.merge(source: "profile_security", label: @passkey.label)
        )

        redirect_to profile_security_path, notice: t("profiles.security.passkeys.deleted")
      end

      private

      def set_passkey
        @passkey = @user.user_passkeys.find(params[:id])
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
        t("mfa.passkeys.errors.#{error}")
      end
    end
  end
end
