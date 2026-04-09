# frozen_string_literal: true

module Users
  module Mfa
    class TotpEnrollmentsController < ApplicationController
      before_action :set_pending_enrollment

      def new
        @provisioning_secret = Auth::PendingMfaSession.pending_totp_secret(session:) || generate_pending_secret!
        @provisioning_uri = @mfa_user.totp_provisioning_uri(secret: @provisioning_secret)
        @qr_code_svg = RQRCode::QRCode.new(@provisioning_uri).as_svg(module_size: 4, standalone: true)
      end

      def create
        @provisioning_secret = Auth::PendingMfaSession.pending_totp_secret(session:) || generate_pending_secret!
        totp = ROTP::TOTP.new(@provisioning_secret, issuer: "Anella")
        timestamp = totp.verify(params[:code].to_s, drift_behind: 30, drift_ahead: 30)

        unless timestamp.present?
          @provisioning_uri = @mfa_user.totp_provisioning_uri(secret: @provisioning_secret)
          @qr_code_svg = RQRCode::QRCode.new(@provisioning_uri).as_svg(module_size: 4, standalone: true)
          flash.now[:alert] = t("mfa.totp_enrollment.errors.invalid_code")
          return render :new, status: :unprocessable_entity
        end

        @mfa_user.update!(
          totp_secret: @provisioning_secret,
          totp_enabled_at: Time.current,
          totp_last_verified_at: Time.at(timestamp),
          totp_consumed_timestep: timestamp.to_i / 30,
          mfa_enabled_at: Time.current
        )

        recovery_codes = Auth::Mfa::GenerateRecoveryCodes.call(user: @mfa_user)
        Auth::PendingMfaSession.store_recovery_codes(session:, codes: recovery_codes)
        Auth::PendingMfaSession.clear_pending_totp_secret(session:)

        AuditLogs::EventLogger.call(
          event_type: "auth.mfa_totp_enabled",
          actor: @mfa_user,
          subject: @mfa_user,
          request: request,
          metadata: audit_context_metadata
        )

        redirect_to user_mfa_recovery_codes_path
      end

      private

      def set_pending_enrollment
        @pending_mfa = Auth::PendingMfaSession.fetch(session:)
        @mfa_user = Auth::PendingMfaSession.pending_user(session:)
        return if @pending_mfa.present? && @mfa_user.present?

        redirect_to new_user_session_path, alert: t("mfa.challenge.expired")
      end

      def generate_pending_secret!
        secret = ROTP::Base32.random
        Auth::PendingMfaSession.store_pending_totp_secret(session:, secret:)
        secret
      end
    end
  end
end
