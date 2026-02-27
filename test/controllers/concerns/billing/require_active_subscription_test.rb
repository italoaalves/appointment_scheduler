# frozen_string_literal: true

require "test_helper"

module Billing
  class RequireActiveSubscriptionTest < ActionDispatch::IntegrationTest
    setup do
      @manager      = users(:manager)
      @space        = spaces(:one)
      @subscription = subscriptions(:one)
    end

    # ── Active / trialing subscription ───────────────────────────────────────

    test "GET is allowed when subscription is trialing" do
      @subscription.update!(status: :trialing)
      sign_in @manager

      get appointments_url
      assert_response :success
      assert_nil flash[:billing_alert]
    end

    test "GET is allowed when subscription is active" do
      @subscription.update!(status: :active)
      sign_in @manager

      get appointments_url
      assert_response :success
    end

    # ── No subscription — grace period ────────────────────────────────────────

    test "GET is allowed when space has no subscription (grace period)" do
      Billing::BillingEvent.where(subscription_id: @subscription.id).delete_all
      Billing::Payment.where(subscription_id: @subscription.id).delete_all
      @subscription.delete
      sign_in @manager

      get appointments_url
      assert_response :success
    end

    # ── Expired subscription ──────────────────────────────────────────────────

    test "GET renders with billing_alert flash when subscription is expired" do
      @subscription.update!(status: :expired)
      sign_in @manager

      get appointments_url
      assert_response :success
      assert_equal I18n.t("billing.restricted_mode.banner"), flash[:billing_alert]
    end

    test "POST is redirected with alert when subscription is expired" do
      @subscription.update!(status: :expired)
      sign_in @manager

      post customers_url, params: { customer: { name: "Test", phone: "+5511999999999" } }
      assert_response :redirect
      assert_equal I18n.t("billing.restricted_mode.write_blocked"), flash[:alert]
    end

    test "PATCH is redirected with alert when subscription is expired" do
      @subscription.update!(status: :expired)
      sign_in @manager

      customer = customers(:one)
      patch customer_url(customer), params: { customer: { name: "Updated" } }
      assert_response :redirect
      assert_equal I18n.t("billing.restricted_mode.write_blocked"), flash[:alert]
    end
  end
end
