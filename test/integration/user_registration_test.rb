# frozen_string_literal: true

require "test_helper"

class UserRegistrationTest < ActionDispatch::IntegrationTest
  test "sign up page requires legal acceptance checkboxes" do
    get new_user_registration_path

    assert_response :success
    assert_select "input[name='user[accept_terms_of_service]'][type='checkbox'][required]"
    assert_select "input[name='user[accept_privacy_policy]'][type='checkbox'][required]"
  end

  test "registration fails without required legal acceptance" do
    assert_no_difference("User.count") do
      post user_registration_path, params: {
        user: {
          name: "Missing Acceptance",
          email: "missing_acceptance@example.com",
          phone_number: "+5511999990100",
          password: "password123",
          accept_terms_of_service: "0",
          accept_privacy_policy: "0"
        }
      }
    end

    assert_response :unprocessable_content
    assert_match I18n.t("activerecord.errors.models.user.attributes.accept_terms_of_service.accepted"), response.body
    assert_match I18n.t("activerecord.errors.models.user.attributes.accept_privacy_policy.accepted"), response.body
  end

  test "registration persists accepted legal versions and timestamps" do
    freeze_time do
      assert_difference("User.count", 1) do
        post user_registration_path, params: {
          user: {
            name: "LGPD Ready",
            email: "lgpd_ready@example.com",
            phone_number: "+5511999990101",
            password: "password123",
            accept_terms_of_service: "1",
            accept_privacy_policy: "1"
          }
        }
      end

      user = User.order(:id).last
      assert_equal Time.current, user.terms_of_service_accepted_at
      assert_equal Time.current, user.privacy_policy_accepted_at
      assert_equal Legal::DocumentCatalog.fetch(:terms_of_service).version, user.terms_of_service_version
      assert_equal Legal::DocumentCatalog.fetch(:privacy_policy).version, user.privacy_policy_version
    end
  end
end
