# frozen_string_literal: true

module Spaces
  class SpaceController < Spaces::BaseController
    include RequirePermission

    require_permission :manage_space, only: [ :edit, :update ]
    before_action :set_space, only: [ :edit, :update ]

    def edit
    end

    def update
      if Spaces::UpdateSettings.call(space: @space, attributes: space_params, banner_upload: banner_upload_param)
        redirect_to edit_settings_space_path, status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_space
      @space = current_tenant
      redirect_to root_path, alert: t("space.settings.no_space") unless @space
    end

    def space_params
      params.require(:space).permit(
        :name,
        :business_type,
        :address,
        :phone,
        :email,
        :booking_success_message,
        :instagram_url,
        :facebook_url
      )
    end

    def banner_upload_param
      params.dig(:space, :banner_upload)
    end
  end
end
