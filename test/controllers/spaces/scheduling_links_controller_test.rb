# frozen_string_literal: true

require "test_helper"

module Spaces
  class SchedulingLinksControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager_starter = users(:manager)      # spaces(:one) — Starter plan, max 3 links
      @manager_pro     = users(:manager_two)  # spaces(:two) — Pro plan, unlimited
    end

    # ── Starter plan — at scheduling link limit ───────────────────────────────
    # spaces(:one) already has 4 scheduling links in fixtures (permanent_link,
    # single_use_link, expired_link, used_link) which is above the Starter limit of 3.

    test "POST create redirects with limit alert when Starter plan is at 3 links" do
      sign_in @manager_starter

      post scheduling_links_url, params: {
        scheduling_link: { name: "Over Limit", link_type: "permanent" }
      }

      assert_redirected_to scheduling_links_url
      assert_equal I18n.t("billing.limits.scheduling_links_exceeded"), flash[:alert]
    end

    # ── Pro plan — unlimited ──────────────────────────────────────────────────

    test "POST create succeeds when Pro plan has no link limit" do
      sign_in @manager_pro

      assert_difference "SchedulingLink.count", 1 do
        post scheduling_links_url, params: {
          scheduling_link: { name: "Pro Link", link_type: "permanent" }
        }
      end

      assert_response :redirect
      assert_not_equal I18n.t("billing.limits.scheduling_links_exceeded"), flash[:alert]
    end
  end
end
