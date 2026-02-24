# frozen_string_literal: true

module Platform
  class UsersController < Platform::BaseController
    before_action :set_user, only: [ :show, :edit, :update, :destroy ]

    def index
      @users = User.includes(:space).order(:email)
      if params[:space_id].present?
        @space_filter = Space.find(params[:space_id])
        @users = @users.where(space_id: params[:space_id])
      end
      @users = @users.page(params[:page]).per(20)
    end

    def show
    end

    def new
      @user = User.new(role: :manager)
    end

    def create
      @user = User.new(user_params)

      if @user.save
        redirect_to platform_user_path(@user), notice: t("platform.users.create.notice")
      else
        render :new
      end
    end

    def edit
    end

    def update
      p = user_params
      p.delete(:password) if p[:password].blank?
      p.delete(:password_confirmation) if p[:password_confirmation].blank?

      if @user.update(p)
        redirect_to platform_user_path(@user), notice: t("platform.users.update.notice")
      else
        render :edit
      end
    end

    def destroy
      @user.destroy
      redirect_to platform_users_path, notice: t("platform.users.destroy.notice")
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:email, :name, :phone_number, :role, :space_id, :password, :password_confirmation)
    end
  end
end
