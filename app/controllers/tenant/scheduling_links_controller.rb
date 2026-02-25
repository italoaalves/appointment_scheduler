# frozen_string_literal: true

module Tenant
  class SchedulingLinksController < Tenant::BaseController
    before_action :set_scheduling_link, only: [ :show, :edit, :update, :destroy ]

    def index
      @scheduling_links = current_tenant.scheduling_links.order(created_at: :desc)
      @personalized_link = current_tenant.personalized_scheduling_link
    end

    def show
    end

    def new
      @scheduling_link = current_tenant.scheduling_links.build
    end

    def create
      @scheduling_link = current_tenant.scheduling_links.build(scheduling_link_params)
      @scheduling_link.expires_at = nil if @scheduling_link.permanent?

      if @scheduling_link.save
        redirect_to scheduling_link_path(@scheduling_link), notice: t("space.scheduling_links.create.notice")
      else
        render :new
      end
    end

    def edit
    end

    def update
      attrs = scheduling_link_params.to_h
      attrs[:expires_at] = nil if attrs["link_type"] == "permanent"
      if @scheduling_link.update(attrs)
        redirect_to scheduling_link_path(@scheduling_link), notice: t("space.scheduling_links.update.notice")
      else
        render :edit
      end
    end

    def destroy
      @scheduling_link.destroy
      redirect_to scheduling_links_path, notice: t("space.scheduling_links.destroy.notice")
    end

    private

    def set_scheduling_link
      @scheduling_link = current_tenant.scheduling_links.find(params[:id])
    end

    def scheduling_link_params
      params.require(:scheduling_link).permit(:name, :link_type, :expires_at)
    end
  end
end
