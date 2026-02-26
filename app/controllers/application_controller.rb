class ApplicationController < ActionController::Base
  include Impersonation

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  before_action :set_locale

  helper UiHelper
  helper_method :current_tenant, :tenant_staff?

  def after_sign_in_path_for(resource)
    return platform_root_path if resource.super_admin?
    return root_path if resource.can?(:access_space_dashboard)

    stored_location_for(resource) || root_path
  end

  private

  def current_tenant
    @current_tenant ||= current_user&.space
  end

  def tenant_staff?
    current_user&.can?(:access_space_dashboard, space: current_user.space)
  end

  def set_locale
    locale = locale_from_user_or_session
    I18n.locale = locale if locale.present?
  end

  def render_not_found
    respond_to do |format|
      format.html { render file: Rails.root.join("public/404.html"), status: :not_found, layout: false }
      format.json { render json: { error: "Not found" }, status: :not_found }
    end
  end

  def render_bad_request(exception)
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: exception.message }
      format.json { render json: { error: exception.message }, status: :bad_request }
    end
  end

  def locale_from_user_or_session
    if user_signed_in? && current_user.user_preference&.locale.present?
      loc = current_user.user_preference.locale
      return loc if I18n.available_locales.map(&:to_s).include?(loc.to_s)
    end

    session_locale = session[:locale]
    if session_locale.present? && I18n.available_locales.map(&:to_s).include?(session_locale.to_s)
      return session_locale
    end

    I18n.default_locale.to_s
  end
end
