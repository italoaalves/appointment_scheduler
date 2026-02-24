# frozen_string_literal: true

class PreferencesController < ApplicationController
  before_action :authenticate_user!

  def edit
    @user_preference = current_user.user_preference || current_user.build_user_preference(locale: I18n.default_locale.to_s)
  end

  def update
    @user_preference = current_user.user_preference || current_user.build_user_preference

    if @user_preference.update(preference_params)
      session[:locale] = @user_preference.locale
      redirect_to edit_preferences_path, notice: t("preferences.update.notice")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def preference_params
    params.require(:user_preference).permit(:locale)
  end
end
