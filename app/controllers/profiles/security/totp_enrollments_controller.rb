# frozen_string_literal: true

module Profiles
  module Security
    class TotpEnrollmentsController < BaseController
      before_action :prepare_enrollment, only: [ :new, :create ]

      def new
      end

      def create
        result = Auth::Mfa::EnrollTotp.call(user: @user, secret: @provisioning_secret, code: params[:code])

        unless result.success?
          flash.now[:alert] = t("mfa.totp_enrollment.errors.#{result.error}")
          return render :new, status: :unprocessable_entity
        end

        Auth::PendingMfaSession.clear_pending_totp_secret(session:)

        AuditLogs::EventLogger.call(
          event_type: "auth.mfa_totp_enabled",
          actor: audit_actor,
          space: current_tenant,
          subject: @user,
          request: request,
          impersonated: impersonating?,
          metadata: audit_context_metadata.merge(source: "profile_security")
        )

        if result.recovery_codes.present?
          Auth::RecoveryCodesDisplaySession.store(session:, user: @user, codes: result.recovery_codes)
          return redirect_to profile_security_recovery_codes_path
        end

        redirect_to profile_security_path, notice: t("profiles.security.totp.enabled")
      end

      def destroy
        result = Auth::Mfa::DisableTotp.call(user: @user)

        unless result.success?
          return redirect_to profile_security_path, alert: t("profiles.security.errors.#{result.error}")
        end

        AuditLogs::EventLogger.call(
          event_type: "auth.mfa_totp_disabled",
          actor: audit_actor,
          space: current_tenant,
          subject: @user,
          request: request,
          impersonated: impersonating?,
          metadata: audit_context_metadata.merge(source: "profile_security")
        )

        redirect_to profile_security_path, notice: t("profiles.security.totp.disabled")
      end

      private

      def prepare_enrollment
        @provisioning_secret = Auth::PendingMfaSession.pending_totp_secret(session:) || generate_pending_secret!
        @provisioning_uri = @user.totp_provisioning_uri(secret: @provisioning_secret)
        @qr_code_svg = RQRCode::QRCode.new(@provisioning_uri).as_svg(module_size: 4, standalone: true)
      end

      def generate_pending_secret!
        secret = ROTP::Base32.random
        Auth::PendingMfaSession.store_pending_totp_secret(session:, secret:)
        secret
      end
    end
  end
end
