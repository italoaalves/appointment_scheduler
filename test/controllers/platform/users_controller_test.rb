# frozen_string_literal: true

require "test_helper"

module Platform
  class UsersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @manager = users(:manager)
      @secretary = users(:secretary)
    end

    test "non-admin is redirected" do
      sign_in @manager
      get platform_users_url
      assert_redirected_to root_url
    end

    test "unauthenticated is redirected to login" do
      get platform_users_url
      assert_redirected_to new_user_session_url
    end

    test "admin can list users" do
      sign_in @admin
      get platform_users_url
      assert_response :success
    end

    test "admin can view user" do
      sign_in @admin
      get platform_user_url(@manager)
      assert_response :success
    end

    test "admin can create user" do
      sign_in @admin
      assert_difference "User.count", 1 do
        post platform_users_url, params: {
          user: {
            email: "newuser@example.com",
            name: "New User",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
    end

    test "admin can update user" do
      sign_in @admin
      patch platform_user_url(@manager), params: {
        user: { name: "Updated Name" }
      }
      assert_redirected_to platform_user_url(@manager)
      assert_equal "Updated Name", @manager.reload.name
    end

    test "admin can destroy user" do
      sign_in @admin
      user_to_delete = User.create!(
        email: "deleteme@example.com",
        password: "password123",
        name: "Delete Me",
        space: spaces(:one)
      )
      assert_difference "User.count", -1 do
        delete platform_user_url(user_to_delete)
      end
    end

    # Impersonation tests
    test "admin can impersonate non-admin user" do
      sign_in @admin
      post impersonate_platform_user_url(@manager)
      assert_redirected_to root_url
      assert_equal @manager.id, session[:impersonated_user_id]
    end

    test "admin cannot impersonate another admin" do
      other_admin = User.create!(
        email: "admin2@example.com",
        password: "password123",
        name: "Admin 2",
        system_role: :super_admin
      )
      sign_in @admin
      post impersonate_platform_user_url(other_admin)
      assert_redirected_to platform_users_url
      assert_nil session[:impersonated_user_id]
    end

    test "impersonation stop clears session" do
      sign_in @admin
      post impersonate_platform_user_url(@manager)
      post platform_stop_impersonation_url
      assert_redirected_to platform_root_url
      assert_nil session[:impersonated_user_id]
    end
  end
end
