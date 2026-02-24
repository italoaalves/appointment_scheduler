# frozen_string_literal: true

module Platform
  class SpacesController < Platform::BaseController
    before_action :set_space, only: [ :show, :edit, :update, :destroy ]

    def index
      @spaces = Space.includes(:users, :customers).order(:name).page(params[:page]).per(20)
    end

    def show
    end

    def new
      @space = Space.new
    end

    def create
      @space = Space.new(space_params)

      if manager_params?
        ActiveRecord::Base.transaction do
          @space.save!
          @manager = User.new(manager_attrs)
          @manager.space_id = @space.id
          @manager.role = :manager
          @manager.save!
        end
        redirect_to platform_space_path(@space), notice: t("platform.spaces.create.notice_with_manager")
      elsif @space.save
        redirect_to platform_space_path(@space), notice: t("platform.spaces.create.notice")
      else
        render :new
      end
    rescue ActiveRecord::RecordInvalid => e
      @manager = e.record if e.record.is_a?(User)
      @space = Space.new(space_params)
      render :new
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

    def manager_params?
      params[:manager_email].present? || params[:manager_password].present?
    end

    def manager_attrs
      {
        email: params[:manager_email],
        name: params[:manager_name].presence,
        password: params[:manager_password],
        password_confirmation: params[:manager_password_confirmation]
      }
    end
  end
end
