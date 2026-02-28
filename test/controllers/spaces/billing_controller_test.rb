# frozen_string_literal: true

require "test_helper"

module Spaces
  class BillingControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager  = users(:manager)       # spaces(:one) — Essential plan, trialing
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

    test "PATCH update with upgrade from essential to pro redirects with success" do
      sign_in @manager

      # subscriptions(:one) has no asaas_subscription_id → no API call
      patch settings_billing_path, params: { billing_plan_id: billing_plans(:pro).id }

      assert_redirected_to settings_billing_path
      assert_equal I18n.t("billing.plan_changed"), flash[:notice]
    end

    test "PATCH update with same plan redirects with no_change alert" do
      sign_in @manager  # already on essential

      patch settings_billing_path, params: { billing_plan_id: billing_plans(:essential).id }

      assert_redirected_to settings_billing_path
      assert_equal I18n.t("billing.no_change"), flash[:alert]
    end

    test "PATCH update with downgrade from pro to essential schedules downgrade" do
      sign_in @manager2  # on pro
      essential = billing_plans(:essential)

      patch settings_billing_path, params: { billing_plan_id: essential.id }

      assert_redirected_to settings_billing_path
      assert_equal I18n.t("billing.downgrade_scheduled"), flash[:notice]
    end

    # ── plan change rate limiting (Bug 3) ─────────────────────────────────────

    test "PATCH update is blocked after 2 plan changes in current billing period" do
      sign_in @manager2  # subscriptions(:two) has current_period_start set

      sub = subscriptions(:two)
      # Simulate 2 already-logged plan changes within this period
      2.times do |i|
        Billing::BillingEvent.create!(
          space_id:        sub.space_id,
          subscription_id: sub.id,
          event_type:      "plan.changed",
          metadata:        { from: "essential", to: "pro", note: "change #{i + 1}" }
        )
      end

      patch settings_billing_path, params: { billing_plan_id: billing_plans(:essential).id }

      assert_redirected_to settings_billing_path
      assert_equal I18n.t("billing.plan_change_limit_reached"), flash[:alert]
    end

    test "PATCH update is allowed when only 1 plan change has happened this period" do
      sign_in @manager2

      sub = subscriptions(:two)
      Billing::BillingEvent.create!(
        space_id:        sub.space_id,
        subscription_id: sub.id,
        event_type:      "plan.changed",
        metadata:        { from: "essential", to: "pro" }
      )

      patch settings_billing_path, params: { billing_plan_id: billing_plans(:essential).id }

      assert_redirected_to settings_billing_path
      assert_equal I18n.t("billing.downgrade_scheduled"), flash[:notice]
    end

    # ── payment method communication (Bug 4) ──────────────────────────────────

    test "upgrade notice appends PIX reminder when subscription uses PIX" do
      sign_in @manager2
      subscriptions(:two).update!(payment_method: :pix)

      patch settings_billing_path, params: { billing_plan_id: billing_plans(:enterprise).id }

      assert_redirected_to settings_billing_path
      assert_includes flash[:notice], I18n.t("billing.payment_method_action_required.pix")
    end

    test "upgrade notice appends boleto reminder when subscription uses boleto" do
      sign_in @manager2
      subscriptions(:two).update!(payment_method: :boleto)

      patch settings_billing_path, params: { billing_plan_id: billing_plans(:enterprise).id }

      assert_redirected_to settings_billing_path
      assert_includes flash[:notice], I18n.t("billing.payment_method_action_required.boleto")
    end

    test "upgrade notice has no reminder for credit card subscriptions" do
      sign_in @manager2
      subscriptions(:two).update!(payment_method: :credit_card)

      patch settings_billing_path, params: { billing_plan_id: billing_plans(:enterprise).id }

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

    # ── checkout ──────────────────────────────────────────────────────────────

    test "GET checkout renders plan selection form" do
      sign_in @manager  # trialing subscription

      get checkout_settings_billing_path

      assert_response :success
    end

    test "GET edit redirects to checkout when subscription is trialing" do
      sign_in @manager  # subscriptions(:one) is trialing

      get edit_settings_billing_path

      assert_redirected_to checkout_settings_billing_path
    end

    test "GET edit renders plan comparison when subscription is active" do
      sign_in @manager2  # subscriptions(:two) is active

      get edit_settings_billing_path

      assert_response :success
    end

    # ── resubscribe ───────────────────────────────────────────────────────────

    test "PATCH resubscribe redirects to checkout page" do
      subscriptions(:one).update!(status: :expired)
      sign_in @manager

      patch resubscribe_settings_billing_path

      assert_redirected_to checkout_settings_billing_path
    end

    # ── subscribe (paid plan) ─────────────────────────────────────────────────

    test "POST subscribe with paid plan calls SubscriptionManager and redirects" do
      sign_in @manager
      subscriptions(:one).update_column(:asaas_customer_id, "cus_existing")

      fake_result = { success: true, subscription: subscriptions(:one) }
      Billing::SubscriptionManager.stub(:subscribe, fake_result) do
        post subscribe_settings_billing_path, params: {
          plan_id: "pro",
          payment_method: "pix",
          cpf_cnpj: "123.456.789-00"
        }
      end

      assert_redirected_to settings_billing_path
      assert_equal I18n.t("billing.checkout.success"), flash[:notice]
      assert_equal "12345678900", @manager.reload.cpf_cnpj
    end

    test "POST subscribe with paid plan on failure renders error" do
      sign_in @manager
      subscriptions(:one).update_column(:asaas_customer_id, "cus_existing")

      fake_result = { success: false, error: "API unavailable" }
      Billing::SubscriptionManager.stub(:subscribe, fake_result) do
        post subscribe_settings_billing_path, params: {
          plan_id: "pro",
          payment_method: "pix",
          cpf_cnpj: "12345678900"
        }
      end

      assert_redirected_to checkout_settings_billing_path
    end

    test "POST subscribe with paid plan rejects missing cpf_cnpj" do
      sign_in @manager

      post subscribe_settings_billing_path, params: {
        plan_id: "pro",
        payment_method: "pix",
        cpf_cnpj: ""
      }

      assert_redirected_to checkout_settings_billing_path
      assert_equal I18n.t("billing.checkout.cpf_cnpj_required"), flash[:alert]
    end

    test "POST subscribe with paid plan rejects invalid cpf_cnpj length" do
      sign_in @manager

      post subscribe_settings_billing_path, params: {
        plan_id: "pro",
        payment_method: "pix",
        cpf_cnpj: "12345"
      }

      assert_redirected_to checkout_settings_billing_path
      assert_equal I18n.t("billing.checkout.cpf_cnpj_invalid"), flash[:alert]
    end
  end
end
