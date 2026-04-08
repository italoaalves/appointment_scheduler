# frozen_string_literal: true

class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user
  before_action :set_active_deletion_request, only: :edit

  def edit
  end

  def update
    if update_profile
      bypass_sign_in(@user, scope: :user) if password_changed?
      redirect_to edit_profile_path
    else
      set_active_deletion_request
      render :edit, status: :unprocessable_entity
    end
  end

  def request_data_export
    DataExports::PackageDeliveryJob.perform_later(@user.id)
    redirect_to edit_profile_path, notice: t("profiles.request_data_export.notice")
  end

  def request_deletion
    result = AccountDeletionRequests::Requester.call(user: @user)

    if result.success?
      redirect_to edit_profile_path, notice: t("profiles.request_deletion.notice")
    else
      redirect_to edit_profile_path, alert: t("profiles.request_deletion.already_pending")
    end
  end

  def cancel_deletion_request
    result = AccountDeletionRequests::Canceler.call(user: @user)

    if result.success?
      redirect_to edit_profile_path, notice: t("profiles.cancel_deletion_request.notice")
    else
      redirect_to edit_profile_path, alert: t("profiles.cancel_deletion_request.not_found")
    end
  end

  private

  def set_user
    @user = current_user
  end

  def set_active_deletion_request
    @active_deletion_request = @user.account_deletion_requests.active.first
  end

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
