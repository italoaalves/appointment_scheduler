# frozen_string_literal: true

require "test_helper"

module Spaces
  class CreditsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager = users(:manager)  # spaces(:one) — has message_credits(:one)
    end

    # ── show ─────────────────────────────────────────────────────────────────

    test "show renders credits page with balance" do
      sign_in @manager

      get settings_credits_path

      assert_response :success
    end

    test "show redirects unauthenticated users" do
      get settings_credits_path
      assert_redirected_to new_user_session_path
    end

    # ── create — success path ─────────────────────────────────────────────────

    test "POST create with valid amount initiates purchase and redirects with notice" do
      sign_in @manager
      spaces(:one).subscription.update_columns(asaas_customer_id: "cus_ctrl_001")

      fake_result = {
        success:      true,
        credit_purchase: Billing::CreditPurchase.new,
        invoice_url: "https://asaas.com/inv/pay_ctrl_001"
      }

      Billing::CreditManager.stub(:initiate_purchase, fake_result) do
        post settings_credits_path, params: { amount: 50 }
      end

      assert_redirected_to settings_credits_path
      assert_equal I18n.t("billing.credits.purchase_initiated"), flash[:notice]
    end

    test "POST create does NOT immediately add balance to MessageCredit" do
      sign_in @manager
      credit          = message_credits(:one)
      initial_balance = credit.balance

      fake_result = {
        success:         true,
        credit_purchase: Billing::CreditPurchase.new,
        invoice_url:     "https://asaas.com/inv/pay_ctrl_002"
      }

      Billing::CreditManager.stub(:initiate_purchase, fake_result) do
        post settings_credits_path, params: { amount: 50 }
      end

      assert_equal initial_balance, credit.reload.balance
    end

    # ── create — failure paths ────────────────────────────────────────────────

    test "POST create with invalid amount redirects with invalid_amount alert" do
      sign_in @manager

      fake_result = { success: false, error: I18n.t("billing.credits.invalid_amount") }

      Billing::CreditManager.stub(:initiate_purchase, fake_result) do
        post settings_credits_path, params: { amount: 75 }
      end

      assert_redirected_to settings_credits_path
      assert_equal I18n.t("billing.credits.invalid_amount"), flash[:alert]
    end

    test "POST create without asaas_customer_id redirects with no_subscription alert" do
      sign_in @manager
      # subscriptions(:one) has no asaas_customer_id by default

      fake_result = { success: false, error: I18n.t("billing.credits.no_subscription") }

      Billing::CreditManager.stub(:initiate_purchase, fake_result) do
        post settings_credits_path, params: { amount: 50 }
      end

      assert_redirected_to settings_credits_path
      assert_equal I18n.t("billing.credits.no_subscription"), flash[:alert]
    end

    test "POST create with Asaas error redirects with error message" do
      sign_in @manager
      spaces(:one).subscription.update_columns(asaas_customer_id: "cus_ctrl_003")

      fake_result = { success: false, error: "Asaas API unavailable" }

      Billing::CreditManager.stub(:initiate_purchase, fake_result) do
        post settings_credits_path, params: { amount: 50 }
      end

      assert_redirected_to settings_credits_path
      assert_equal "Asaas API unavailable", flash[:alert]
    end
  end
end
