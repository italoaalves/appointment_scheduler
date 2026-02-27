# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    def sign_up_params
      p = params.require(:user).permit(:name, :email, :password)
      p[:password_confirmation] = p[:password]
      p
    end

    def after_sign_up_path_for(_resource)
      onboarding_path
    end
  end
end
