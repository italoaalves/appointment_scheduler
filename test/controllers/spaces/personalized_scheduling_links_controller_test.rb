# frozen_string_literal: true

require "test_helper"

module Spaces
  class PersonalizedSchedulingLinksControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager_starter = users(:manager)      # spaces(:one) — Starter plan (no personalized page)
      @manager_pro     = users(:manager_two)  # spaces(:two) — Pro plan (feature available)
    end

    # ── Starter plan — feature not available ─────────────────────────────────

    test "GET new redirects with feature_not_available alert on Starter plan" do
      sign_in @manager_starter

      get new_personalized_scheduling_link_url

      assert_redirected_to scheduling_links_url
      assert_equal I18n.t("billing.limits.feature_not_available"), flash[:alert]
    end

    test "POST create redirects with feature_not_available alert on Starter plan" do
      sign_in @manager_starter

      post personalized_scheduling_link_url, params: {
        personalized_scheduling_link: { slug: "my-clinic" }
      }

      assert_redirected_to scheduling_links_url
      assert_equal I18n.t("billing.limits.feature_not_available"), flash[:alert]
    end

    # ── Pro plan — feature available ──────────────────────────────────────────

    test "GET new renders form for Pro plan" do
      sign_in @manager_pro

      get new_personalized_scheduling_link_url

      assert_response :success
    end
  end
end
