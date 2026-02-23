# frozen_string_literal: true

module Admin
  class SchedulingLinksController < Admin::BaseController
    before_action :set_scheduling_link, only: [ :show, :edit, :update, :destroy ]

    def index
      @scheduling_links = current_tenant.scheduling_links.order(created_at: :desc)
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
        redirect_to admin_scheduling_link_path(@scheduling_link), notice: t("admin.scheduling_links.create.notice")
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
        redirect_to admin_scheduling_link_path(@scheduling_link), notice: t("admin.scheduling_links.update.notice")
      else
        render :edit
      end
    end

    def destroy
      @scheduling_link.destroy
      redirect_to admin_scheduling_links_path, notice: t("admin.scheduling_links.destroy.notice")
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
