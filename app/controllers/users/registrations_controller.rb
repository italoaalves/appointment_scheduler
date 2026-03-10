# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    def build_resource(hash = {})
      super
      resource.require_phone_number = true
    end

    def sign_up_params
      p = params.require(:user).permit(:name, :email, :password, :phone_number)
      p[:password_confirmation] = p[:password]
      p
    end

    def after_sign_up_path_for(_resource)
      onboarding_wizard_path
    end
  end
end
