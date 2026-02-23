# frozen_string_literal: true

require "test_helper"

module Admin
  class UsersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager = users(:manager)
      @secretary = users(:secretary)
      @admin = users(:admin)
    end

    test "redirects unauthenticated to login" do
      get admin_users_url
      assert_redirected_to new_user_session_url
    end

    test "redirects admin role to root" do
      sign_in @admin
      get admin_users_url
      assert_redirected_to root_url
    end

    test "manager can get index" do
      sign_in @manager
      get admin_users_url
      assert_response :success
    end

    test "secretary can get index" do
      sign_in @secretary
      get admin_users_url
      assert_response :success
    end

    test "index shows only current tenant users" do
      sign_in @manager
      get admin_users_url
      assert_response :success
      # Space one has manager and secretary only
      assert_select "table tbody tr", count: 2
    end

    test "manager can create secretary" do
      sign_in @manager
      assert_difference "User.count", 1 do
        post admin_users_url, params: {
          user: {
            email: "newsecretary@test.com",
            name: "New Secretary",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
      assert_redirected_to admin_user_url(User.last)
      new_user = User.last
      assert new_user.secretary?
      assert_equal @manager.space_id, new_user.space_id
    end

    test "secretary cannot create team member" do
      sign_in @secretary
      assert_no_difference "User.count" do
        post admin_users_url, params: {
          user: {
            email: "hacker@test.com",
            name: "Hacker",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
      assert_redirected_to admin_users_url
    end

    test "manager can update team member" do
      sign_in @manager
      patch admin_user_url(@secretary), params: {
        user: { name: "Updated Secretary", email: @secretary.email }
      }
      assert_redirected_to admin_users_url
      @secretary.reload
      assert_equal "Updated Secretary", @secretary.name
    end

    test "manager cannot access other tenant user" do
      other_manager = users(:manager_two)
      sign_in @manager
      get admin_user_url(other_manager)
      assert_response :not_found
    end
  end
end
