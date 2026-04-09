# frozen_string_literal: true

module Users
  module Mfa
    class RecoveryCodesController < ApplicationController
      include Devise::Controllers::Rememberable

      before_action :set_pending_recovery_codes

      def show
      end

      def create
        remember_me_requested = @pending_mfa[:remember_me]
        return_to = @pending_mfa[:return_to]

        @mfa_user.update!(last_mfa_at: Time.current)
        Auth::PendingMfaSession.clear_recovery_codes(session:)

        sign_in(:user, @mfa_user)
        Auth::PendingMfaSession.mark_verified!(session:, user: @mfa_user)
        remember_me(@mfa_user) if remember_me_requested

        redirect_to(return_to.presence || after_sign_in_path_for(@mfa_user))
      end

      private

      def set_pending_recovery_codes
        @pending_mfa = Auth::PendingMfaSession.fetch(session:)
        @mfa_user = Auth::PendingMfaSession.pending_user(session:)
        @recovery_codes = Auth::PendingMfaSession.recovery_codes(session:)
        return if @pending_mfa.present? && @mfa_user.present? && @recovery_codes.present?

        redirect_to new_user_session_path, alert: t("mfa.challenge.expired")
      end
    end
  end
end
