# frozen_string_literal: true

require "test_helper"

module Billing
  class CreditManagerTest < ActiveSupport::TestCase
    setup do
      @space  = spaces(:one)
      @credit = message_credits(:one)  # balance: 50, monthly_quota_remaining: 150
    end

    # ── purchase ──────────────────────────────────────────────────────────────

    test "purchase increases balance by the given amount" do
      result = Billing::CreditManager.purchase(space: @space, amount: 50)

      @credit.reload
      assert result[:success]
      assert_equal 100, @credit.balance
      assert_equal 100, result[:new_balance]
    end

    test "purchase logs a BillingEvent with credits.purchased" do
      assert_difference "Billing::BillingEvent.count", 1 do
        Billing::CreditManager.purchase(space: @space, amount: 100)
      end

      event = Billing::BillingEvent.order(:created_at).last
      assert_equal "credits.purchased", event.event_type
      assert_equal 100, event.metadata["amount"]
    end

    test "purchase with actor records actor_id on the event" do
      actor = users(:manager)
      Billing::CreditManager.purchase(space: @space, amount: 50, actor: actor)

      event = Billing::BillingEvent.order(:created_at).last
      assert_equal actor.id, event.actor_id
    end

    test "purchase raises RecordNotFound for an amount with no active bundle" do
      assert_raises ActiveRecord::RecordNotFound do
        Billing::CreditManager.purchase(space: @space, amount: 999)
      end
    end

    test "purchase raises RecordNotFound for an inactive bundle" do
      credit_bundles(:fifty).update!(active: false)

      assert_raises ActiveRecord::RecordNotFound do
        Billing::CreditManager.purchase(space: @space, amount: 50)
      end
    end

    # ── deduct ────────────────────────────────────────────────────────────────

    test "deduct decrements monthly_quota_remaining first" do
      result = Billing::CreditManager.deduct(space: @space)

      @credit.reload
      assert result[:success]
      assert_equal :quota, result[:source]
      assert_equal 149, @credit.monthly_quota_remaining
      assert_equal 50,  @credit.balance
    end

    test "deduct falls back to balance when quota is 0" do
      @credit.update!(monthly_quota_remaining: 0)

      result = Billing::CreditManager.deduct(space: @space)

      @credit.reload
      assert result[:success]
      assert_equal :purchased, result[:source]
      assert_equal 49, @credit.balance
      assert_equal 0,  @credit.monthly_quota_remaining
    end

    test "deduct returns insufficient when both are 0" do
      @credit.update!(monthly_quota_remaining: 0, balance: 0)

      result = Billing::CreditManager.deduct(space: @space)

      assert_not result[:success]
      assert_equal :insufficient_credits, result[:reason]
    end

    test "deduct does not change balance when quota is available" do
      result = Billing::CreditManager.deduct(space: @space)

      @credit.reload
      assert_equal 50, @credit.balance
      assert result[:success]
    end

    test "deduct returns unlimited source and skips credit record for unlimited plan" do
      enterprise_space = Space.create!(name: "Enterprise Space", timezone: "UTC")
      Billing::Subscription.create!(
        space:        enterprise_space,
        billing_plan: billing_plans(:enterprise),
        status:       :active
      )

      result = Billing::CreditManager.deduct(space: enterprise_space)

      assert result[:success]
      assert_equal :unlimited, result[:source]
      assert_nil Billing::MessageCredit.find_by(space_id: enterprise_space.id)
    end

    # ── refund ────────────────────────────────────────────────────────────────

    test "refund with :quota source increments monthly_quota_remaining" do
      Billing::CreditManager.refund(space: @space, source: :quota)

      @credit.reload
      assert_equal 151, @credit.monthly_quota_remaining
    end

    test "refund with :purchased source increments balance" do
      Billing::CreditManager.refund(space: @space, source: :purchased)

      @credit.reload
      assert_equal 51, @credit.balance
    end

    test "refund returns success: true" do
      result = Billing::CreditManager.refund(space: @space, source: :quota)

      assert result[:success]
    end

    test "refund with :unlimited source is a no-op and returns success" do
      result = Billing::CreditManager.refund(space: @space, source: :unlimited)

      assert result[:success]
      @credit.reload
      assert_equal 50,  @credit.balance
      assert_equal 150, @credit.monthly_quota_remaining
    end

    # ── sufficient? ───────────────────────────────────────────────────────────

    test "sufficient? returns true when balance > 0 and quota is 0" do
      @credit.update!(balance: 10, monthly_quota_remaining: 0)

      assert Billing::CreditManager.sufficient?(space: @space)
    end

    test "sufficient? returns true when monthly_quota_remaining > 0 and balance is 0" do
      @credit.update!(balance: 0, monthly_quota_remaining: 10)

      assert Billing::CreditManager.sufficient?(space: @space)
    end

    test "sufficient? returns true when both are > 0" do
      assert Billing::CreditManager.sufficient?(space: @space)
    end

    test "sufficient? returns false when both are 0" do
      @credit.update!(balance: 0, monthly_quota_remaining: 0)

      assert_not Billing::CreditManager.sufficient?(space: @space)
    end

    test "sufficient? returns false when no MessageCredit record exists" do
      @credit.delete

      assert_not Billing::CreditManager.sufficient?(space: @space)
    end

    test "sufficient? returns true for unlimited plan regardless of credits" do
      enterprise_space = Space.create!(name: "Enterprise Sufficient Space", timezone: "UTC")
      Billing::Subscription.create!(
        space:        enterprise_space,
        billing_plan: billing_plans(:enterprise),
        status:       :active
      )

      assert Billing::CreditManager.sufficient?(space: enterprise_space)
    end

    # ── initiate_purchase ─────────────────────────────────────────────────────

    test "initiate_purchase creates a pending CreditPurchase and returns invoice_url" do
      @space.subscription.update_columns(asaas_customer_id: "cus_test_001", payment_method: :pix)

      fake_client = Object.new
      fake_client.define_singleton_method(:create_payment) do |**_|
        { "id" => "pay_cp_001", "invoiceUrl" => "https://asaas.com/inv/pay_cp_001" }
      end

      result = Billing::CreditManager.initiate_purchase(
        space:        @space,
        amount:       50,
        actor:        users(:manager),
        asaas_client: fake_client
      )

      assert result[:success]
      assert_equal "https://asaas.com/inv/pay_cp_001", result[:invoice_url]

      purchase = Billing::CreditPurchase.find_by(asaas_payment_id: "pay_cp_001")
      assert_not_nil purchase
      assert purchase.pending?
      assert_equal 50, purchase.amount
      assert_equal users(:manager).id, purchase.actor_id
    end

    test "initiate_purchase does NOT immediately add balance" do
      @space.subscription.update_columns(asaas_customer_id: "cus_test_002", payment_method: :pix)

      fake_client = Object.new
      fake_client.define_singleton_method(:create_payment) do |**_|
        { "id" => "pay_cp_002", "invoiceUrl" => "https://asaas.com/inv/pay_cp_002" }
      end

      assert_no_difference -> { @credit.reload.balance } do
        Billing::CreditManager.initiate_purchase(space: @space, amount: 50, asaas_client: fake_client)
      end
    end

    test "initiate_purchase returns error when subscription has no asaas_customer_id" do
      # subscriptions(:one) has no asaas_customer_id by default

      result = Billing::CreditManager.initiate_purchase(space: @space, amount: 50)

      assert_not result[:success]
      assert_equal I18n.t("billing.credits.no_subscription"), result[:error]
      assert_equal 0, Billing::CreditPurchase.where(space: @space).count
    end

    test "initiate_purchase returns error for invalid amount" do
      @space.subscription.update_columns(asaas_customer_id: "cus_test_003", payment_method: :pix)

      result = Billing::CreditManager.initiate_purchase(space: @space, amount: 999)

      assert_not result[:success]
      assert_equal I18n.t("billing.credits.invalid_amount"), result[:error]
      assert_equal 0, Billing::CreditPurchase.where(space: @space).count
    end

    test "initiate_purchase marks CreditPurchase as failed when Asaas API errors" do
      @space.subscription.update_columns(asaas_customer_id: "cus_test_004", payment_method: :pix)

      failing_client = Object.new
      failing_client.define_singleton_method(:create_payment) do |**_|
        raise Billing::AsaasClient::ApiError.new(503, "Asaas is down")
      end

      result = Billing::CreditManager.initiate_purchase(
        space:        @space,
        amount:       50,
        asaas_client: failing_client
      )

      assert_not result[:success]
      assert_includes result[:error], "Asaas is down"

      purchase = Billing::CreditPurchase.where(space: @space).last
      assert_not_nil purchase
      assert purchase.failed?
    end

    # ── fulfill_purchase ──────────────────────────────────────────────────────

    test "fulfill_purchase grants credits and marks CreditPurchase as completed" do
      purchase = Billing::CreditPurchase.create!(
        space:         @space,
        credit_bundle: credit_bundles(:fifty),
        amount:        50,
        price_cents:   2500,
        status:        :pending
      )

      result = Billing::CreditManager.fulfill_purchase(space: @space, credit_purchase: purchase)

      assert result[:success]
      assert purchase.reload.completed?
      assert_equal 100, @credit.reload.balance  # was 50, now 100
    end

    test "fulfill_purchase is idempotent — calling twice does not double-grant credits" do
      purchase = Billing::CreditPurchase.create!(
        space:         @space,
        credit_bundle: credit_bundles(:fifty),
        amount:        50,
        price_cents:   2500,
        status:        :pending
      )

      Billing::CreditManager.fulfill_purchase(space: @space, credit_purchase: purchase)
      Billing::CreditManager.fulfill_purchase(space: @space, credit_purchase: purchase)

      assert_equal 100, @credit.reload.balance  # added only once
    end

    test "fulfill_purchase returns success: true when already completed" do
      purchase = Billing::CreditPurchase.create!(
        space:         @space,
        credit_bundle: credit_bundles(:fifty),
        amount:        50,
        price_cents:   2500,
        status:        :completed
      )

      result = Billing::CreditManager.fulfill_purchase(space: @space, credit_purchase: purchase)

      assert result[:success]
    end

    # ── advisory lock ─────────────────────────────────────────────────────────

    test "deduct executes advisory lock SQL inside transaction" do
      sql_log = []

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        sql_log << payload[:sql]
      end

      Billing::CreditManager.deduct(space: @space)

      lock_sql = sql_log.find { |sql| sql.include?("pg_advisory_xact_lock") }
      assert lock_sql, "Expected pg_advisory_xact_lock to appear in SQL log"

      # Must use $1 bind parameter, not string interpolation
      assert_match(/pg_advisory_xact_lock\(\$1\)/, lock_sql,
        "Advisory lock must use a bind parameter ($1), not string interpolation")
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end
end
