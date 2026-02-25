# frozen_string_literal: true

module Space
  class UsersController < Space::BaseController
    include StripBlankPasswordParams
    include RequirePermission

    require_permission :manage_team, only: [ :new, :create, :edit, :update, :destroy ], redirect_to: :users_path
    before_action :set_user, only: [ :show, :edit, :update, :destroy ]

    def index
      @users = current_tenant.users.order(:email)
    end

    def show
    end

    def new
      @user = current_tenant.users.build
    end

    def create
      @user = current_tenant.users.build(user_params)

      if @user.save
        redirect_to user_path(@user), notice: t("space.users.create.notice")
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @user.update(user_params_without_blank_passwords)
        redirect_to users_path, notice: t("space.users.update.notice")
      else
        render :edit
      end
    end

    def destroy
      @user.destroy
      redirect_to users_path, notice: t("space.users.destroy.notice")
    end

    private

    def set_user
      @user = current_tenant.users.find(params[:id])
    end

    def user_params
      permitted = [ :email, :name, :phone_number, :password, :password_confirmation, :role ]
      permitted << { permission_names_param: [] } if current_user.can?(:manage_team)
      params.require(:user).permit(permitted)
    end
  end
end
