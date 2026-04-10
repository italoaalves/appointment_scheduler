# frozen_string_literal: true

module Users
  module Mfa
    class ChallengesController < ApplicationController
      include Devise::Controllers::Rememberable

      before_action :set_pending_challenge

      def show
        redirect_to new_user_mfa_totp_enrollment_path if @mfa_user.mfa_setup_required?
      end

      def create
        result =
          if params[:otp_attempt].present?
            Auth::Mfa::VerifyTotp.call(user: @mfa_user, code: params[:otp_attempt])
          elsif params[:recovery_code_attempt].present?
            Auth::Mfa::VerifyRecoveryCode.call(user: @mfa_user, code: params[:recovery_code_attempt])
          else
            Struct.new(:success?, :error, keyword_init: true).new(success?: false, error: :blank_code)
          end

        unless result.success?
          log_challenge_failure(result.error)
          attempts = Auth::PendingMfaSession.increment_attempts!(session:)

          if attempts >= Auth::PendingMfaSession::MAX_ATTEMPTS
            Auth::PendingMfaSession.clear(session:)
            return redirect_to new_user_session_path, alert: t("mfa.challenge.expired")
          end

          flash.now[:alert] = t("mfa.challenge.errors.#{result.error}")
          return render :show, status: :unprocessable_entity
        end

        finalize_sign_in!
      end

      private

      def set_pending_challenge
        @pending_mfa = Auth::PendingMfaSession.fetch(session:)
        @mfa_user = Auth::PendingMfaSession.pending_user(session:)
        return if @pending_mfa.present? && @mfa_user.present?

        redirect_to new_user_session_path, alert: t("mfa.challenge.expired")
      end

      def finalize_sign_in!
        remember_me_requested = @pending_mfa[:remember_me]
        return_to = @pending_mfa[:return_to]

        @mfa_user.update!(last_mfa_at: Time.current)
        sign_in(:user, @mfa_user)
        Auth::PendingMfaSession.mark_verified!(session:, user: @mfa_user)
        remember_me(@mfa_user) if remember_me_requested

        log_challenge_success
        redirect_to(return_to.presence || after_sign_in_path_for(@mfa_user))
      end

      def log_challenge_success
        AuditLogs::EventLogger.call(
          event_type: "auth.mfa_challenge_succeeded",
          actor: @mfa_user,
          subject: @mfa_user,
          request: request,
          metadata: audit_context_metadata
        )
      end

      def log_challenge_failure(error)
        AuditLogs::EventLogger.call(
          event_type: "auth.mfa_challenge_failed",
          subject: @mfa_user,
          request: request,
          metadata: audit_context_metadata.merge(error: error.to_s)
        )
      end
    end
  end
end
