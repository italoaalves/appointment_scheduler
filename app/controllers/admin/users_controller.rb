class Admin::UsersController < ApplicationController
  before_action :require_admin
  before_action :set_user, only: [ :show, :edit, :update, :destroy ]

  def index
    @users = User.all
  end

  def show
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to admin_user_path(@user), notice: "Client created."
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
      redirect_to admin_users_path, notice: "Client updated."
    else
      render :edit
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_path
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :name, :phone_number, :role, :password, :password_confirmation)
  end

  def require_admin
    redirect_to root_path unless current_user.admin?
  end
end
