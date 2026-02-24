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
    locale = locale_from_user_or_session
    I18n.locale = locale if locale.present?
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
