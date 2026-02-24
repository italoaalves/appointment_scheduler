# frozen_string_literal: true

module Admin
  class UsersController < Admin::BaseController
    include StripBlankPasswordParams

    before_action :set_user, only: [ :show, :edit, :update, :destroy ]
    before_action :require_manager, only: [ :new, :create, :edit, :update, :destroy ]

    def index
      @users = current_tenant.users.order(:email)
    end

    def show
    end

    def new
      @user = current_tenant.users.build(role: :secretary)
    end

    def create
      @user = current_tenant.users.build(user_params)
      @user.role = :secretary

      if @user.save
        redirect_to admin_user_path(@user), notice: t("admin.users.create.notice")
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @user.update(user_params_without_blank_passwords)
        redirect_to admin_users_path, notice: t("admin.users.update.notice")
      else
        render :edit
      end
    end

    def destroy
      @user.destroy
      redirect_to admin_users_path, notice: t("admin.users.destroy.notice")
    end

    private

    def set_user
      @user = current_tenant.users.find(params[:id])
    end

    def user_params
      permitted = [ :email, :name, :phone_number, :password, :password_confirmation ]
      permitted << :role if current_user.manager?
      params.require(:user).permit(permitted)
    end

    def require_manager
      return if current_user.manager?

      redirect_to admin_users_path, alert: t("admin.users.manager_only")
    end
  end
end
