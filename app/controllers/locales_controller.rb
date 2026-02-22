class LocalesController < ApplicationController
  def update
    locale = params[:locale].to_s

    if I18n.available_locales.map(&:to_s).include?(locale)
      session[:locale] = locale
    end

    redirect_back fallback_location: root_path
  end
end
