# frozen_string_literal: true

require "test_helper"

module Spaces
  class BillingControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager  = users(:manager)       # spaces(:one) — Starter plan, trialing
      @manager2 = users(:manager_two)   # spaces(:two) — Pro plan, active
    end

    # ── show ─────────────────────────────────────────────────────────────────

    test "show renders billing page with subscription details" do
      sign_in @manager

      get settings_billing_path

      assert_response :success
    end

    test "show is accessible when subscription is expired (exempt from restricted mode)" do
      subscriptions(:one).update!(status: :expired)
      sign_in @manager

      get settings_billing_path

      assert_response :success
    end

    test "show redirects unauthenticated users" do
      get settings_billing_path
      assert_redirected_to new_user_session_path
    end

    # ── update (upgrade) ──────────────────────────────────────────────────────

    test "PATCH update with upgrade from starter to pro redirects with success" do
      sign_in @manager

      # subscriptions(:one) has no asaas_subscription_id → no API call
      patch settings_billing_path, params: { plan_id: "pro" }

      assert_redirected_to settings_billing_path
      assert_equal I18n.t("billing.plan_changed"), flash[:notice]
    end

    test "PATCH update with same plan redirects with no_change alert" do
      sign_in @manager  # already on starter

      patch settings_billing_path, params: { plan_id: "starter" }

      assert_redirected_to settings_billing_path
      assert_equal I18n.t("billing.no_change"), flash[:alert]
    end

    test "PATCH update with downgrade from pro to starter schedules downgrade" do
      sign_in @manager2  # on pro

      patch settings_billing_path, params: { plan_id: "starter" }

      assert_redirected_to settings_billing_path
      assert_equal I18n.t("billing.plan_changed"), flash[:notice]
    end

    # ── cancel ────────────────────────────────────────────────────────────────

    test "PATCH cancel calls SubscriptionManager.cancel and redirects with notice" do
      sign_in @manager2  # active subscription, no asaas_subscription_id → no API call

      patch cancel_settings_billing_path

      assert_redirected_to settings_billing_path
      assert_equal I18n.t("billing.canceled"), flash[:notice]
      assert subscriptions(:two).reload.canceled?
    end
  end
end
