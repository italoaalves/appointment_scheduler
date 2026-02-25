# frozen_string_literal: true

module Tenant
  class SpaceController < Tenant::BaseController
    include RequirePermission

    require_permission :manage_space, only: [ :edit, :update ]
    before_action :set_space, only: [ :edit, :update ]

    def edit
    end

    def update
      if @space.update(space_params)
        redirect_to edit_settings_space_path, notice: t("space.space.update.notice")
      else
        render :edit
      end
    end

    private

    def set_space
      @space = current_tenant
      redirect_to root_path, alert: t("space.space.no_space") unless @space
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
  end
end
