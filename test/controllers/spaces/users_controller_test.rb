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
  end
end
