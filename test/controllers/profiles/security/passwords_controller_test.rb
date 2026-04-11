# frozen_string_literal: true

require "test_helper"

class Profiles::Security::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:manager_two)
  end

  test "user can update password from the security page" do
    sign_in @user

    patch profile_security_password_path, params: {
      user: {
        current_password: "password123",
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to profile_security_path
    follow_redirect!
    assert_response :success
    assert @user.reload.valid_password?("newpassword123")
  end

  test "invalid password update re-renders the security page" do
    sign_in @user

    patch profile_security_password_path, params: {
      user: {
        current_password: "wrong-password",
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_response :unprocessable_entity
    assert_select "h1", text: I18n.t("profiles.security.title")
    assert_select "form[action='#{profile_security_password_path}']"
  end
end
