# frozen_string_literal: true

class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user
  before_action :set_active_deletion_request, only: :edit

  def edit
  end

  def update
    if update_profile
      redirect_to edit_profile_path, status: :see_other
    else
      set_active_deletion_request
      render :edit, status: :unprocessable_entity
    end
  end

  def request_data_export
    DataExports::PackageDeliveryJob.perform_later(@user.id)
    AuditLogs::EventLogger.call(
      event_type: "privacy.export_requested",
      actor: audit_actor,
      space: current_tenant,
      subject: @user,
      request: request,
      impersonated: impersonating?,
      metadata: audit_context_metadata.merge(source: "profile_settings")
    )
    redirect_to edit_profile_path, notice: t("profiles.request_data_export.notice")
  end

  def request_deletion
    result = AccountDeletionRequests::Requester.call(
      user: @user,
      actor: audit_actor,
      request: request,
      metadata: audit_context_metadata.merge(source: "profile_settings", impersonated: impersonating?)
    )

    if result.success?
      redirect_to edit_profile_path, notice: t("profiles.request_deletion.notice")
    else
      redirect_to edit_profile_path, alert: t("profiles.request_deletion.already_pending")
    end
  end

  def cancel_deletion_request
    result = AccountDeletionRequests::Canceler.call(
      user: @user,
      actor: audit_actor,
      request: request,
      metadata: audit_context_metadata.merge(source: "profile_settings", impersonated: impersonating?)
    )

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
    Profiles::UpdateSettings.call(
      user: @user,
      attributes: profile_params,
      profile_picture_upload: profile_picture_upload_param
    )
  end

  def profile_params
    p = params.require(:user).permit(:name, :phone_number)
    strip_phone_if_trialing(p)
  end

  def profile_picture_upload_param
    params.dig(:user, :profile_picture_upload)
  end

  # Defense-in-depth: strip phone_number from params when the user is on trial
  # so even a crafted request cannot bypass the model validation.
  def strip_phone_if_trialing(permitted)
    return permitted if current_user.super_admin?
    return permitted unless current_user.space&.subscription&.trialing?

    permitted.except(:phone_number)
  end
end
