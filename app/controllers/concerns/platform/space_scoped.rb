# frozen_string_literal: true

module Platform
  module SpaceScoped
    extend ActiveSupport::Concern

    included do
      before_action :set_space
    end

    private

    def set_space
      @space = Space.find(params[:space_id])
    end
  end
end
