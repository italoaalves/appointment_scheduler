class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_locale

  helper_method :current_tenant, :tenant_staff?

  private

  def current_tenant
    @current_tenant ||= current_user&.space
  end

  def tenant_staff?
    current_user&.manager? || current_user&.secretary?
  end

  def set_locale
    session_locale = session[:locale]
    if session_locale.present? && I18n.available_locales.map(&:to_s).include?(session_locale.to_s)
      I18n.locale = session_locale
    else
      I18n.locale = I18n.default_locale
    end
  end
end
