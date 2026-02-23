# frozen_string_literal: true

module Platform
  class SpacesController < Platform::BaseController
    before_action :set_space, only: [ :show, :edit, :update, :destroy ]

    def index
      @spaces = Space.includes(:users, :clients).order(:name)
    end

    def show
    end

    def new
      @space = Space.new
    end

    def create
      @space = Space.new(space_params)

      if @space.save
        redirect_to platform_space_path(@space), notice: t("platform.spaces.create.notice")
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @space.update(space_params)
        redirect_to platform_space_path(@space), notice: t("platform.spaces.update.notice")
      else
        render :edit
      end
    end

    def destroy
      @space.destroy
      redirect_to platform_spaces_path, notice: t("platform.spaces.destroy.notice")
    end

    private

    def set_space
      @space = Space.find(params[:id])
    end

    def space_params
      params.require(:space).permit(:name, :timezone)
    end
  end
end
