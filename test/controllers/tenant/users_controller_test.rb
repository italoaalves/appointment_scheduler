# frozen_string_literal: true

require "test_helper"

module Tenant
  class UsersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager = users(:manager)
      @secretary = users(:secretary)
      @admin = users(:admin)
    end

    test "redirects unauthenticated to login" do
      get users_url
      assert_redirected_to new_user_session_url
    end

    test "redirects admin role to platform" do
      sign_in @admin
      get users_url
      assert_redirected_to platform_root_url
    end

    test "manager can get index" do
      sign_in @manager
      get users_url
      assert_response :success
    end

    test "secretary can get index" do
      sign_in @secretary
      get users_url
      assert_response :success
    end

    test "index shows only current tenant users" do
      sign_in @manager
      get users_url
      assert_response :success
      assert_select "table tbody tr", count: 2
    end

    test "manager can create secretary" do
      # spaces(:two) is on Pro plan (max 5 members, currently 1) — no plan limit block
      manager_pro = users(:manager_two)
      sign_in manager_pro
      assert_difference "User.count", 1 do
        post users_url, params: {
          user: {
            email: "newsecretary@test.com",
            name: "New Secretary",
            password: "password123",
            password_confirmation: "password123",
            role: "Secretary",
            permission_names_param: %w[access_space_dashboard manage_customers manage_appointments manage_scheduling_links]
          }
        }
      end
      assert_redirected_to user_url(User.last)
      new_user = User.last
      assert new_user.can?(:access_space_dashboard)
      assert new_user.can?(:manage_customers)
      refute new_user.can?(:manage_team)
      assert_equal manager_pro.space&.id, new_user.space&.id
    end

    test "secretary cannot create team member" do
      sign_in @secretary
      assert_no_difference "User.count" do
        post users_url, params: {
          user: {
            email: "hacker@test.com",
            name: "Hacker",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
      assert_redirected_to users_url
    end

    test "manager can update team member role and permissions" do
      sign_in @manager
      patch user_url(@secretary), params: {
        user: {
          role: "Assistant",
          permission_names_param: %w[access_space_dashboard manage_appointments]
        }
      }
      assert_redirected_to users_url
      @secretary.reload
      assert_equal "Assistant", @secretary.role
      assert @secretary.can?(:access_space_dashboard)
      assert @secretary.can?(:manage_appointments)
      refute @secretary.can?(:manage_customers)
    end

    test "manager cannot access other tenant user" do
      other_manager = users(:manager_two)
      sign_in @manager
      get user_url(other_manager)
      assert_response :not_found
    end
  end
end
