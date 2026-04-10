# frozen_string_literal: true

require "test_helper"

class SocialAuthenticationTest < ActionDispatch::IntegrationTest
  test "sign in and sign up pages show social provider buttons" do
    get new_user_session_path

    assert_response :success
    assert_select "form[action='#{user_google_oauth2_omniauth_authorize_path}'][method='post']"
    assert_select "form[action='#{user_apple_omniauth_authorize_path}'][method='post']"

    get new_user_registration_path

    assert_response :success
    assert_select "form[action='#{user_google_oauth2_omniauth_authorize_path}'][method='post']"
    assert_select "form[action='#{user_apple_omniauth_authorize_path}'][method='post']"
  end

  test "forgot password page shows social provider buttons" do
    get new_user_password_path

    assert_response :success
    assert_select "form[action='#{user_google_oauth2_omniauth_authorize_path}'][method='post']"
    assert_select "form[action='#{user_apple_omniauth_authorize_path}'][method='post']"
  end

  test "new google signup goes through finish signup and onboarding" do
    OmniAuth.config.mock_auth[:google_oauth2] = omniauth_hash(
      provider: :google_oauth2,
      uid: "google-integration",
      email: "social_integration@example.com",
      name: "Social Integration"
    )

    assert_no_difference("User.count") do
      post user_google_oauth2_omniauth_callback_path
    end

    assert_redirected_to new_user_social_registration_path
    follow_redirect!

    assert_response :success
    assert_select "input[name='user[email]'][readonly][value='social_integration@example.com']"
    assert_select "input[name='user[accept_terms_of_service]'][required]"
    assert_select "input[name='user[accept_privacy_policy]'][required]"

    assert_difference("User.count", 1) do
      assert_difference("UserIdentity.count", 1) do
        post user_social_registration_path, params: {
          user: {
            name: "Social Integration",
            phone_number: "+5511999990888",
            accept_terms_of_service: "1",
            accept_privacy_policy: "1"
          }
        }
      end
    end

    assert_redirected_to onboarding_wizard_path

    user = User.find_by!(email: "social_integration@example.com")
    assert user.confirmed?
    assert user.user_identities.exists?(provider: "google_oauth2", uid: "google-integration")
  end

  test "provider failure redirects back to the sign in page" do
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials

    post user_google_oauth2_omniauth_callback_path

    assert_redirected_to new_user_session_path
  end
end
