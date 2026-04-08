# frozen_string_literal: true

require "test_helper"

module Spaces
  class UsersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager_starter = users(:manager)       # spaces(:one) — Starter plan, 2 members (at limit)
      @manager_pro     = users(:manager_two)   # spaces(:two) — Pro plan, 1 member (under limit)
    end

    # ── Starter plan — at team member limit ──────────────────────────────────

    test "POST create redirects with limit alert when Starter plan is at member limit" do
      sign_in @manager_starter

      post users_url, params: { user: { email: "new@example.com", name: "New Member" } }

      assert_redirected_to users_url
      assert_equal I18n.t("billing.limits.team_members_exceeded"), flash[:alert]
    end

    test "GET new shows limit message when Starter plan is at member limit" do
      sign_in @manager_starter

      get new_user_url

      assert_redirected_to users_url
      assert_equal I18n.t("billing.limits.team_members_exceeded"), flash[:alert]
    end

    # ── Pro plan — under limit ────────────────────────────────────────────────

    test "POST create succeeds when Pro plan is under member limit" do
      sign_in @manager_pro

      assert_difference "User.count", 1 do
        post users_url, params: {
          user: { email: "newmember_#{SecureRandom.hex(4)}@example.com", name: "New Member" }
        }
      end

      assert_response :redirect
      assert_not_equal I18n.t("billing.limits.team_members_exceeded"), flash[:alert]
    end

    # ── Infinite scroll ───────────────────────────────────────────────────────

    test "GET index returns turbo frame with infinite scroll" do
      sign_in @manager_pro
      get users_url, headers: { "Turbo-Frame" => "users-feed" }

      assert_response :success
      assert_select "turbo-frame#users-feed"
    end

    test "GET index with page parameter returns next page of users" do
      sign_in @manager_pro
      # Create additional users to test pagination
      25.times do |i|
        @manager_pro.space.users.create!(
          email: "paginated#{i}@example.com",
          name: "Paginated User #{i}",
          role: "member",
          password: SecureRandom.hex(16)
        )
      end

      get users_url, params: { page: 2 }, headers: { "Turbo-Frame" => "users-feed" }

      assert_response :success
      assert_select "turbo-frame#users-feed"
      # The second page should have the paginated users
      assert_select "div.user-card", minimum: 1
    end

    test "GET index filters users by email query" do
      sign_in @manager_pro
      @manager_pro.space.users.create!(
        email: "searchtest@example.com",
        name: "Search Test User",
        password: SecureRandom.hex(16)
      )

      get users_url, params: { query: "searchtest" }, headers: { "Turbo-Frame" => "users-feed" }

      assert_response :success
      assert_select "turbo-frame#users-feed"
      assert_select "div.user-card", minimum: 1
    end

    test "GET index filters users by name query" do
      sign_in @manager_pro
      @manager_pro.space.users.create!(
        email: "another@example.com",
        name: "Special Name User",
        password: SecureRandom.hex(16)
      )

      get users_url, params: { query: "Special Name" }, headers: { "Turbo-Frame" => "users-feed" }

      assert_response :success
      assert_select "turbo-frame#users-feed"
      assert_select "div.user-card", minimum: 1
    end

    test "POST create denied by missing permission writes audit log" do
      sign_in users(:secretary)

      assert_difference "AuditLog.count", 1 do
        post users_url, params: { user: { email: "blocked@example.com", name: "Blocked User" } }
      end

      assert_redirected_to users_url
      log = AuditLog.order(:id).last
      assert_equal "authorization.permission_denied", log.event_type
      assert_equal users(:secretary), log.actor
    end

    test "PATCH update logs permission changes" do
      sign_in @manager_pro
      team_member = @manager_pro.space.users.create!(
        email: "permission-target-#{SecureRandom.hex(4)}@example.com",
        name: "Permission Target",
        password: SecureRandom.hex(16)
      )

      assert_difference "AuditLog.count", 1 do
        patch user_url(team_member), params: {
          user: {
            role: "Assistant",
            permission_names_param: [ "manage_customers", "read_inbox" ]
          }
        }
      end

      assert_redirected_to users_url
      log = AuditLog.order(:id).last
      assert_equal "authorization.team_permissions_changed", log.event_type
      assert_equal team_member.id, log.subject_id
    end
  end
end
