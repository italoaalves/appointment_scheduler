# frozen_string_literal: true

module Spaces
  class PersonalizedSchedulingLinksController < Spaces::BaseController
    include RequirePermission

    require_permission :manage_personalized_links, redirect_to: :scheduling_links_path
    before_action :set_personalized_link, only: [ :edit, :update, :destroy ]

    def new
      if current_tenant.personalized_scheduling_link.present?
        redirect_to edit_personalized_scheduling_link_path, alert: t("space.personalized_scheduling_links.new.already_exists")
        return
      end
      @personalized_link = current_tenant.build_personalized_scheduling_link
    end

    def create
      @personalized_link = current_tenant.build_personalized_scheduling_link(personalized_link_params)
      if @personalized_link.save
        redirect_to scheduling_links_path, notice: t("space.personalized_scheduling_links.create.notice")
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @personalized_link.update(personalized_link_params)
        redirect_to scheduling_links_path, notice: t("space.personalized_scheduling_links.update.notice")
      else
        render :edit
      end
    end

    def destroy
      @personalized_link.destroy
      redirect_to scheduling_links_path, notice: t("space.personalized_scheduling_links.destroy.notice")
    end

    private

    def set_personalized_link
      @personalized_link = current_tenant.personalized_scheduling_link
      redirect_to scheduling_links_path, alert: t("space.personalized_scheduling_links.not_found") unless @personalized_link
    end

    def personalized_link_params
      params.require(:personalized_scheduling_link).permit(:slug)
    end
  end
end
