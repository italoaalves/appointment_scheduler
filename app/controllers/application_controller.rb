class ApplicationController < ActionController::Base
  include Impersonation
  include MfaEnforcement

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from StandardError, with: :render_internal_server_error
  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  before_action :set_locale
  around_action :with_error_context

  helper UiHelper
  helper_method :current_tenant, :tenant_staff?, :current_subscription, :subscription_restricted?

  def current_subscription
    Current.subscription
  end

  def subscription_restricted?
    false
  end

  def after_sign_in_path_for(resource)
    return platform_root_path if resource.super_admin?

    if resource.can?(:access_space_dashboard)
      space = resource.space
      return onboarding_wizard_path if space.present? && !space.onboarding_complete? && resource.space_owner?
      return dashboard_path
    end

    stored_location_for(resource) || dashboard_path
  end

  private

  def audit_actor
    real_current_user || current_user
  end

  def audit_context_metadata
    {
      controller: controller_path,
      action: action_name,
      method: request.request_method
    }
  end

  def current_tenant
    @current_tenant ||= current_user&.space
  end

  def tenant_staff?
    current_user&.can?(:access_space_dashboard, space: current_user.space)
  end

  def set_locale
    I18n.locale = locale_from_user_or_browser
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

  def render_internal_server_error(exception)
    Observability::UnexpectedErrorReporter.report(
      exception,
      handled: false,
      source: "application.controller",
      context: Observability::UnexpectedErrorReporter.controller_context(self)
    )

    respond_to do |format|
      format.html do
        render "errors/internal_server_error",
          status: :internal_server_error,
          layout: false,
          locals: { request_id: request.request_id }
      end
      format.json do
        render json: {
          error: t("errors.internal_server_error.message"),
          request_id: request.request_id
        }, status: :internal_server_error
      end
      format.any { head :internal_server_error }
    end
  end

  def locale_from_user_or_browser
    if user_signed_in?
      return current_user_preferred_locale || I18n.default_locale.to_s
    end

    LocaleResolver.from_accept_language(request.get_header("HTTP_ACCEPT_LANGUAGE")) || I18n.default_locale.to_s
  end

  def current_user_preferred_locale
    LocaleResolver.normalize(current_user.user_preference&.locale)
  end

  def available_locale?(locale)
    available_locales.include?(locale.to_s)
  end

  def available_locales
    I18n.available_locales.map(&:to_s)
  end

  def with_error_context(&block)
    Rails.error.set_context(**Observability::UnexpectedErrorReporter.controller_context(self), &block)
  end
end
