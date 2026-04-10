# frozen_string_literal: true

module Profiles
  module Security
    class RecoveryCodesController < BaseController
      before_action :set_recovery_codes, only: :show

      def show
      end

      def regenerate
        return redirect_to profile_security_path, alert: t("profiles.security.recovery_codes.unavailable") unless @user.mfa_enabled?

        recovery_codes = Auth::Mfa::GenerateRecoveryCodes.call(user: @user)
        Auth::RecoveryCodesDisplaySession.store(session:, user: @user, codes: recovery_codes)

        AuditLogs::EventLogger.call(
          event_type: "auth.mfa_recovery_codes_regenerated",
          actor: audit_actor,
          space: current_tenant,
          subject: @user,
          request: request,
          impersonated: impersonating?,
          metadata: audit_context_metadata.merge(source: "profile_security")
        )

        redirect_to profile_security_recovery_codes_path
      end

      def acknowledge
        Auth::RecoveryCodesDisplaySession.clear(session:)
        redirect_to profile_security_path, notice: t("profiles.security.recovery_codes.acknowledged")
      end

      private

      def set_recovery_codes
        @recovery_codes = Auth::RecoveryCodesDisplaySession.codes(session:, user: @user)
        return if @recovery_codes.present?

        redirect_to profile_security_path, alert: t("profiles.security.recovery_codes.missing")
      end
    end
  end
end
