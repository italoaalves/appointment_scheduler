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

    # ── create ────────────────────────────────────────────────────────────────

    test "POST create with valid amount (50) adds credits and redirects with notice" do
      sign_in @manager
      credit = message_credits(:one)
      initial_balance = credit.balance

      post settings_credits_path, params: { amount: 50 }

      assert_redirected_to settings_credits_path
      assert_equal I18n.t("billing.credits.purchased", amount: 50), flash[:notice]
      assert_equal initial_balance + 50, credit.reload.balance
    end

    test "POST create with valid amount (100) adds credits" do
      sign_in @manager
      credit = message_credits(:one)
      initial_balance = credit.balance

      post settings_credits_path, params: { amount: 100 }

      assert_redirected_to settings_credits_path
      assert_equal initial_balance + 100, credit.reload.balance
    end

    test "POST create with valid amount (200) adds credits" do
      sign_in @manager
      credit = message_credits(:one)
      initial_balance = credit.balance

      post settings_credits_path, params: { amount: 200 }

      assert_redirected_to settings_credits_path
      assert_equal initial_balance + 200, credit.reload.balance
    end

    test "POST create with invalid amount redirects with error" do
      sign_in @manager
      credit = message_credits(:one)
      initial_balance = credit.balance

      post settings_credits_path, params: { amount: 75 }

      assert_redirected_to settings_credits_path
      assert_equal I18n.t("billing.credits.invalid_amount"), flash[:alert]
      assert_equal initial_balance, credit.reload.balance
    end

    test "POST create logs a BillingEvent" do
      sign_in @manager

      assert_difference "Billing::BillingEvent.count", 1 do
        post settings_credits_path, params: { amount: 50 }
      end
    end
  end
end
