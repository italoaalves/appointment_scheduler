# frozen_string_literal: true

module Profiles
  module Security
    class PasswordsController < BaseController
      def update
        if update_password
          bypass_sign_in(@user, scope: :user) if password_changed?
          redirect_to profile_security_path, notice: t("profiles.security.password.updated"), status: :see_other
        else
          load_security_overview
          render "profiles/security/show", status: :unprocessable_entity
        end
      end

      private

      def update_password
        Profiles::UpdateSettings.call(
          user: @user,
          attributes: {},
          password_attributes: password_params,
          profile_picture_upload: nil
        )
      end

      def password_changed?
        @user.previous_changes.key?("encrypted_password")
      end

      def password_params
        params.require(:user).permit(:current_password, :password, :password_confirmation)
      end
    end
  end
end
