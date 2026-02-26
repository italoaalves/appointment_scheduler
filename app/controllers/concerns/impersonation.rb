# frozen_string_literal: true

module Impersonation
  extend ActiveSupport::Concern

  included do
    helper_method :impersonating?, :real_current_user
    before_action :validate_impersonation, if: :impersonating?
  end

  def impersonating?
    session[:impersonated_user_id].present?
  end

  # The actual authenticated user (admin). Use for authorization that must not
  # be affected by impersonation (e.g. require_platform_admin).
  def real_current_user
    @real_current_user ||= warden&.authenticate(scope: :user)
  end

  # Effective user: impersonated user when impersonating, else the signed-in user.
  def current_user
    if impersonating?
      @impersonated_user ||= User.find_by(id: session[:impersonated_user_id])
    else
      real_current_user
    end
  end

  private

  def validate_impersonation
    return if User.exists?(session[:impersonated_user_id])

    session.delete(:impersonated_user_id)
    redirect_to platform_root_path, alert: t("platform.impersonation.user_not_found")
  end
end
