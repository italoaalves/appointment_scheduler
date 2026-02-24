# frozen_string_literal: true

module Admin
  class SpaceController < Admin::BaseController
    before_action :require_manager
    before_action :set_space, only: [ :edit, :update ]

    def edit
    end

    def update
      if @space.update(space_params)
        redirect_to edit_admin_space_path, notice: t("admin.space.update.notice")
      else
        render :edit
      end
    end

    private

    def set_space
      @space = current_tenant
      redirect_to root_path, alert: t("admin.space.no_space") unless @space
    end

    def require_manager
      return if current_user.manager?

      redirect_to root_path, alert: t("admin.users.manager_only")
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
