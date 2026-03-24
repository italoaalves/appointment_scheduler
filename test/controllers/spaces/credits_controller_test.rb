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

    # ── checkout ──────────────────────────────────────────────────────────────

    test "GET checkout renders page with bundle summary and payment method selector" do
      sign_in @manager

      get checkout_settings_credits_path, params: { bundle_id: credit_bundles(:fifty).id }

      assert_response :success
      assert_includes response.body, I18n.t("billing.credits.checkout.title")
      assert_includes response.body, I18n.t("billing.credits.checkout.confirm")
    end

    test "GET checkout returns 404 for unknown bundle_id" do
      sign_in @manager

      get checkout_settings_credits_path, params: { bundle_id: 0 }

      assert_response :not_found
    end

    test "GET checkout redirects unauthenticated users" do
      get checkout_settings_credits_path, params: { bundle_id: credit_bundles(:fifty).id }

      assert_redirected_to new_user_session_path
    end

    # ── create — success path ─────────────────────────────────────────────────

    test "POST create with bundle_id and pix redirects to payment page" do
      sign_in @manager

      purchase = spaces(:one).credit_purchases.create!(
        credit_bundle: credit_bundles(:fifty),
        amount: 50, price_cents: 2500, status: :pending,
        pix_qr_code_base64: "base64qr==", pix_payload: "00020101..."
      )

      Billing::CreditManager.stub(:initiate_purchase, { success: true, credit_purchase: purchase }) do
        post settings_credits_path, params: { bundle_id: credit_bundles(:fifty).id, payment_method: "pix" }
      end

      assert_redirected_to payment_settings_credits_path(purchase_id: purchase.id)
    end

    test "POST create with boleto redirects to payment page" do
      sign_in @manager

      purchase = spaces(:one).credit_purchases.create!(
        credit_bundle: credit_bundles(:fifty),
        amount: 50, price_cents: 2500, status: :pending,
        bank_slip_url: "https://asaas.com/boleto/slip.pdf"
      )

      Billing::CreditManager.stub(:initiate_purchase, { success: true, credit_purchase: purchase }) do
        post settings_credits_path, params: { bundle_id: credit_bundles(:fifty).id, payment_method: "boleto" }
      end

      assert_redirected_to payment_settings_credits_path(purchase_id: purchase.id)
    end

    test "POST create with credit_card redirects to payment page" do
      sign_in @manager

      purchase = spaces(:one).credit_purchases.create!(
        credit_bundle: credit_bundles(:fifty),
        amount: 50, price_cents: 2500, status: :pending
      )

      Billing::CreditManager.stub(:initiate_purchase, { success: true, credit_purchase: purchase }) do
        post settings_credits_path, params: { bundle_id: credit_bundles(:fifty).id, payment_method: "credit_card" }
      end

      assert_redirected_to payment_settings_credits_path(purchase_id: purchase.id)
    end

    test "POST create with invalid payment_method defaults to pix" do
      sign_in @manager

      received_payment_method = nil
      stub_result = { success: true, credit_purchase: spaces(:one).credit_purchases.create!(
        credit_bundle: credit_bundles(:fifty), amount: 50, price_cents: 2500, status: :pending
      ) }

      Billing::CreditManager.stub(:initiate_purchase, ->(space:, bundle:, payment_method:, actor:) {
        received_payment_method = payment_method
        stub_result
      }) do
        post settings_credits_path, params: { bundle_id: credit_bundles(:fifty).id, payment_method: "invalid" }
      end

      assert_equal :pix, received_payment_method
    end

    # ── payment ───────────────────────────────────────────────────────────────

    test "GET payment shows the PIX QR code for a pending purchase" do
      sign_in @manager

      purchase = spaces(:one).credit_purchases.create!(
        credit_bundle:      credit_bundles(:fifty),
        amount:             50,
        price_cents:        2500,
        status:             :pending,
        pix_qr_code_base64: "base64qr==",
        pix_payload:        "00020101..."
      )

      get payment_settings_credits_path, params: { purchase_id: purchase.id }

      assert_response :success
      assert_includes response.body, "base64qr=="
      assert_includes response.body, "00020101..."
    end

    test "GET payment is scoped to current tenant" do
      sign_in @manager

      other_purchase = spaces(:two).credit_purchases.create!(
        credit_bundle:      credit_bundles(:fifty),
        amount:             50,
        price_cents:        2500,
        status:             :pending,
        pix_qr_code_base64: "base64qr=="
      )

      get payment_settings_credits_path, params: { purchase_id: other_purchase.id }

      assert_response :not_found
    end

    test "GET payment redirects unauthenticated users" do
      purchase = spaces(:one).credit_purchases.create!(
        credit_bundle: credit_bundles(:fifty),
        amount:        50,
        price_cents:   2500,
        status:        :pending
      )

      get payment_settings_credits_path, params: { purchase_id: purchase.id }

      assert_redirected_to new_user_session_path
    end

    test "POST create does NOT immediately add balance to MessageCredit" do
      sign_in @manager
      credit          = message_credits(:one)
      initial_balance = credit.balance

      purchase    = spaces(:one).credit_purchases.create!(
        credit_bundle: credit_bundles(:fifty), amount: 50, price_cents: 2500, status: :pending
      )
      fake_result = { success: true, credit_purchase: purchase }

      Billing::CreditManager.stub(:initiate_purchase, fake_result) do
        post settings_credits_path, params: { bundle_id: credit_bundles(:fifty).id, payment_method: "pix" }
      end

      assert_equal initial_balance, credit.reload.balance
    end

    test "show renders Boleto link for pending Boleto purchase" do
      sign_in @manager
      spaces(:one).credit_purchases.create!(
        credit_bundle: credit_bundles(:fifty),
        amount:        50,
        price_cents:   2500,
        status:        :pending,
        bank_slip_url: "https://asaas.com/boleto/slip_001.pdf"
      )

      get settings_credits_path

      assert_response :success
      assert_includes response.body, I18n.t("billing.credits.show.view_boleto")
      assert_includes response.body, "https://asaas.com/boleto/slip_001.pdf"
    end

    test "show renders clearing warning for pending Boleto purchase" do
      sign_in @manager
      spaces(:one).credit_purchases.create!(
        credit_bundle: credit_bundles(:fifty),
        amount:        50,
        price_cents:   2500,
        status:        :pending,
        bank_slip_url: "https://asaas.com/boleto/slip_002.pdf"
      )

      get settings_credits_path

      assert_response :success
      assert_includes response.body, I18n.t("billing.credits.boleto_clearing_warning")
    end

    test "show does NOT render Boleto link for non-Boleto pending purchase" do
      sign_in @manager
      spaces(:one).credit_purchases.create!(
        credit_bundle: credit_bundles(:fifty),
        amount:        50,
        price_cents:   2500,
        status:        :pending,
        invoice_url:   "https://asaas.com/inv/pix_001"
      )

      get settings_credits_path

      assert_response :success
      assert_not_includes response.body, I18n.t("billing.credits.show.view_boleto")
    end

    # ── status ────────────────────────────────────────────────────────────────

    test "GET status returns JSON status for a pending purchase" do
      sign_in @manager

      purchase = spaces(:one).credit_purchases.create!(
        credit_bundle: credit_bundles(:fifty),
        amount:        50,
        price_cents:   2500,
        status:        :pending
      )

      get status_settings_credits_path, params: { purchase_id: purchase.id }

      assert_response :success
      assert_equal "application/json", response.content_type.split(";").first
      assert_equal({ "status" => "pending" }, JSON.parse(response.body))
    end

    test "GET status returns JSON status for a completed purchase" do
      sign_in @manager

      purchase = spaces(:one).credit_purchases.create!(
        credit_bundle: credit_bundles(:fifty),
        amount:        50,
        price_cents:   2500,
        status:        :completed
      )

      get status_settings_credits_path, params: { purchase_id: purchase.id }

      assert_response :success
      assert_equal({ "status" => "completed" }, JSON.parse(response.body))
    end

    test "GET status is scoped to current tenant" do
      sign_in @manager

      other_purchase = spaces(:two).credit_purchases.create!(
        credit_bundle: credit_bundles(:fifty),
        amount:        50,
        price_cents:   2500,
        status:        :pending
      )

      get status_settings_credits_path, params: { purchase_id: other_purchase.id }

      assert_response :not_found
    end

    test "GET status redirects unauthenticated users" do
      purchase = spaces(:one).credit_purchases.create!(
        credit_bundle: credit_bundles(:fifty),
        amount:        50,
        price_cents:   2500,
        status:        :pending
      )

      get status_settings_credits_path, params: { purchase_id: purchase.id }

      assert_redirected_to new_user_session_path
    end

    # ── show — PIX QR code link ───────────────────────────────────────────────

    test "show renders View QR Code link for pending PIX purchase with QR code" do
      sign_in @manager
      spaces(:one).credit_purchases.create!(
        credit_bundle:      credit_bundles(:fifty),
        amount:             50,
        price_cents:        2500,
        status:             :pending,
        pix_qr_code_base64: "base64qr=="
      )

      get settings_credits_path

      assert_response :success
      assert_includes response.body, I18n.t("billing.credits.show.view_qr_code")
    end

    test "show does NOT render View QR Code link for Boleto pending purchase" do
      sign_in @manager
      spaces(:one).credit_purchases.create!(
        credit_bundle: credit_bundles(:fifty),
        amount:        50,
        price_cents:   2500,
        status:        :pending,
        bank_slip_url: "https://asaas.com/boleto/slip_003.pdf"
      )

      get settings_credits_path

      assert_response :success
      assert_not_includes response.body, I18n.t("billing.credits.show.view_qr_code")
    end

    # ── create — failure paths ────────────────────────────────────────────────

    test "POST create with invalid bundle_id returns 404" do
      sign_in @manager

      post settings_credits_path, params: { bundle_id: 0, payment_method: "pix" }

      assert_response :not_found
    end

    test "POST create when manager returns error redirects to credits with alert" do
      sign_in @manager

      fake_result = { success: false, error: I18n.t("billing.credits.no_subscription") }

      Billing::CreditManager.stub(:initiate_purchase, fake_result) do
        post settings_credits_path, params: { bundle_id: credit_bundles(:fifty).id, payment_method: "pix" }
      end

      assert_redirected_to settings_credits_path
      assert_equal I18n.t("billing.credits.no_subscription"), flash[:alert]
    end
  end
end
