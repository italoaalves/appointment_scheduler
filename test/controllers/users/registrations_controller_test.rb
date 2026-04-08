# frozen_string_literal: true

require "test_helper"

module Users
  class RegistrationsControllerTest < ActionDispatch::IntegrationTest
    test "registration with valid phone number succeeds" do
      post user_registration_path, params: {
        user: {
          name: "New User",
          email: "new_user@example.com",
          phone_number: "+5511999990099",
          password: "password123",
          accept_terms_of_service: "1",
          accept_privacy_policy: "1"
        }
      }

      assert_response :redirect
      user = User.find_by(email: "new_user@example.com")
      assert_not_nil user
      assert_equal "+5511999990099", user.phone_number
    end

    test "registration without phone number fails" do
      post user_registration_path, params: {
        user: {
          name: "No Phone",
          email: "no_phone@example.com",
          phone_number: "",
          password: "password123",
          accept_terms_of_service: "1",
          accept_privacy_policy: "1"
        }
      }

      assert_response :unprocessable_entity
      assert_nil User.find_by(email: "no_phone@example.com")
    end

    test "registration with duplicate phone number fails with generic message" do
      existing = User.find_by!(email: "manager@example.com")
      existing.update_column(:phone_number, "+5511999990050")

      post user_registration_path, params: {
        user: {
          name: "Dup Phone",
          email: "dup_phone@example.com",
          phone_number: "+5511999990050",
          password: "password123",
          accept_terms_of_service: "1",
          accept_privacy_policy: "1"
        }
      }

      assert_response :unprocessable_entity
      assert_nil User.find_by(email: "dup_phone@example.com")
      # Generic message — does not say "has already been taken"
      assert_no_match(/already been taken/, response.body)
      assert_match(/não pôde ser verificado/, response.body)
    end

    test "phone number is normalized before saving" do
      post user_registration_path, params: {
        user: {
          name: "Fmt User",
          email: "fmt_user@example.com",
          phone_number: "(55) 11 99999-0088",
          password: "password123",
          accept_terms_of_service: "1",
          accept_privacy_policy: "1"
        }
      }

      assert_response :redirect
      user = User.find_by(email: "fmt_user@example.com")
      assert_not_nil user
      # (55) 11 99999-0088 → digits: 5511999990088 → +5511999990088
      assert_equal "+5511999990088", user.phone_number
    end
  end
end
