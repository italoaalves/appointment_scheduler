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
      result = Billing::CreditManager.purchase(space: @space, amount: 10)

      @credit.reload
      assert result[:success]
      assert_equal 60, @credit.balance
      assert_equal 60, result[:new_balance]
    end

    test "purchase logs a BillingEvent with credits.purchased" do
      assert_difference "Billing::BillingEvent.count", 1 do
        Billing::CreditManager.purchase(space: @space, amount: 25)
      end

      event = Billing::BillingEvent.order(:created_at).last
      assert_equal "credits.purchased", event.event_type
      assert_equal 25, event.metadata["amount"]
    end

    test "purchase with actor records actor_id on the event" do
      actor = users(:manager)
      Billing::CreditManager.purchase(space: @space, amount: 5, actor: actor)

      event = Billing::BillingEvent.order(:created_at).last
      assert_equal actor.id, event.actor_id
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

    # ── advisory lock ─────────────────────────────────────────────────────────

    test "deduct executes advisory lock SQL inside transaction" do
      lock_key = Zlib.crc32("message_credits:#{@space.id}")
      sql_log  = []

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        sql_log << payload[:sql]
      end

      Billing::CreditManager.deduct(space: @space)

      assert sql_log.any? { |sql| sql.include?("pg_advisory_xact_lock") && sql.include?(lock_key.to_s) },
             "Expected pg_advisory_xact_lock(#{lock_key}) to appear in SQL log"
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end
end
