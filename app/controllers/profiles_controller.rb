# frozen_string_literal: true

class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if update_profile
      bypass_sign_in(@user, scope: :user) if password_changed?
      redirect_to edit_profile_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def update_profile
    if password_params?
      @user.update_with_password(profile_params_with_password)
    else
      @user.update(profile_params)
    end
  end

  def password_params?
    profile_params_with_password[:password].present?
  end

  def password_changed?
    password_params? && @user.previous_changes.key?("encrypted_password")
  end

  def profile_params
    p = params.require(:user).permit(:name, :phone_number)
    strip_phone_if_trialing(p)
  end

  def profile_params_with_password
    p = params.require(:user).permit(:name, :phone_number, :current_password, :password, :password_confirmation)
    strip_phone_if_trialing(p)
  end

  # Defense-in-depth: strip phone_number from params when the user is on trial
  # so even a crafted request cannot bypass the model validation.
  def strip_phone_if_trialing(permitted)
    return permitted if current_user.super_admin?
    return permitted unless current_user.space&.subscription&.trialing?

    permitted.except(:phone_number)
  end
end
