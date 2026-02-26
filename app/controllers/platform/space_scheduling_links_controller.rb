# frozen_string_literal: true

module Platform
  class SpaceSchedulingLinksController < Platform::BaseController
    include Platform::SpaceScoped

    def index
      @scheduling_links = @space.scheduling_links.order(created_at: :desc).page(params[:page]).per(20)
    end

    def show
      @scheduling_link = @space.scheduling_links.find(params[:id])
    end
  end
end
