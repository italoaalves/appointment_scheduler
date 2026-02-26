# frozen_string_literal: true

module Spaces
  class UsersController < Spaces::BaseController
    include RequirePermission

    require_permission :manage_team, only: [ :new, :create, :edit, :update, :destroy ], redirect_to: :users_path
    before_action :set_user, only: [ :show, :edit, :update, :destroy ]

    def index
      @users = current_tenant.users.order(:email).page(params[:page]).per(20)
    end

    def show
    end

    def new
      @user = User.new
      @user.space_id = current_tenant.id
    end

    def create
      @user = User.new(user_params)
      @user.space_id = current_tenant.id
      @user.password = SecureRandom.hex(32)

      if @user.save
        @user.send_reset_password_instructions
        redirect_to user_path(@user), notice: t("space.users.create.notice")
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @user.update(update_user_params)
        redirect_to users_path, notice: t("space.users.update.notice")
      else
        render :edit
      end
    end

    def destroy
      if @user.space_owner?(current_tenant)
        redirect_to users_path, alert: t("space.users.destroy.cannot_remove_owner")
        return
      end
      @user.destroy
      redirect_to users_path, notice: t("space.users.destroy.notice")
    end

    private

    def set_user
      @user = current_tenant.users.find(params[:id])
    end

    def user_params
      permitted = [ :email, :name, :phone_number, :role ]
      permitted << { permission_names_param: [] } if current_user.can?(:manage_team, space: current_tenant)
      params.require(:user).permit(permitted)
    end

    def update_user_params
      permitted = [ :role ]
      permitted << { permission_names_param: [] } if current_user.can?(:manage_team, space: current_tenant)
      params.require(:user).permit(permitted)
    end
  end
end
