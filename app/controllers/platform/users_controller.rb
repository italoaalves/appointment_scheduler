# frozen_string_literal: true

module Platform
  class UsersController < Platform::BaseController
    include StripBlankPasswordParams

    before_action :set_user, only: [ :show, :edit, :update, :destroy, :impersonate ]

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
      @user = User.new
      if params[:space_id].present?
        space = Space.find_by(id: params[:space_id])
        @user.space_id = space.id if space
      end
    end

    def create
      @user = User.new(user_params)
      @user.space_id = params[:user][:space_id].presence if params.dig(:user, :space_id).present?

      if @user.save
        redirect_to platform_user_path(@user), notice: t("platform.users.create.notice")
      else
        render :new
      end
    end

    def edit
    end

    def update
      attrs = user_params_without_blank_passwords
      attrs[:space_id] = params[:user][:space_id].presence if params.dig(:user, :space_id).present?

      if @user.update(attrs)
        redirect_to platform_user_path(@user), notice: t("platform.users.update.notice")
      else
        render :edit
      end
    end

    def destroy
      space_id = params[:space_id].presence
      @user.destroy
      redirect_to platform_users_path(space_id: space_id), notice: t("platform.users.destroy.notice")
    end

    def impersonate
      if @user.super_admin?
        redirect_to platform_users_path, alert: t("platform.impersonation.cannot_impersonate_admin")
        return
      end

      session[:impersonated_user_id] = @user.id
      Rails.logger.info(
        "[IMPERSONATION_START] admin_id=#{real_current_user.id} " \
        "admin_email=#{real_current_user.email} " \
        "impersonated_id=#{@user.id} " \
        "impersonated_email=#{@user.email} " \
        "at=#{Time.current.iso8601}"
      )
      redirect_to root_path, notice: t("platform.impersonation.started", name: @user.name.presence || @user.email)
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:email, :name, :phone_number, :password, :password_confirmation, :role, permission_names_param: [])
    end
  end
end
