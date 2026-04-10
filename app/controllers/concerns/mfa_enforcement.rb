# frozen_string_literal: true

module MfaEnforcement
  extend ActiveSupport::Concern

  included do
    before_action :enforce_mfa, if: :user_signed_in?
  end

  private

  def enforce_mfa
    return unless current_user.super_admin?
    return if Auth::PendingMfaSession.verified?(session: session, user: current_user)
    return if controller_path.start_with?("users/mfa")

    if current_user.mfa_setup_required?
      redirect_to new_user_mfa_totp_enrollment_path
    elsif current_user.mfa_enabled?
      redirect_to user_mfa_challenge_path
    end
  end
end
