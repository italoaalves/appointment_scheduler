# frozen_string_literal: true

require "test_helper"

module Billing
  class SyncSubscriptionStateJobTest < ActiveJob::TestCase
    class FakeClient
      attr_reader :cancelled_ids

      # "PAST_DUE" is not in STATUS_MAP so reconcile is a no-op — safe default for
      # grace period tests that don't care about the Asaas remote sync pass.
      def initialize(remote_status: "PAST_DUE", raise_on_find: false, raise_on_cancel: false)
        @remote_status  = remote_status
        @raise_on_find  = raise_on_find
        @raise_on_cancel = raise_on_cancel
        @cancelled_ids  = []
      end

      def find_subscription(_id)
        raise Billing::AsaasClient::ApiError.new(500, "fail") if @raise_on_find

        { "status" => @remote_status }
      end

      def cancel_subscription(id)
        raise Billing::AsaasClient::ApiError.new(500, "fail") if @raise_on_cancel

        @cancelled_ids << id
      end
    end

    setup do
      @space = Space.create!(name: "Sync Job Space #{SecureRandom.hex(4)}", timezone: "UTC")
      Billing::TrialManager.start_trial(@space)
      @subscription = @space.reload.subscription
      @subscription.update!(
        status:                :past_due,
        asaas_subscription_id: "sub_asaas_001",
        current_period_end:    31.days.ago
      )
    end

    # ── Grace period expiry (new behaviour) ──────────────────────────────────

    test "expires past_due subscription when grace period is exhausted" do
      Billing::SyncSubscriptionStateJob.new.perform(client: FakeClient.new)

      assert @subscription.reload.expired?
    end

    test "calls Asaas DELETE when asaas_subscription_id present" do
      client = FakeClient.new

      Billing::SyncSubscriptionStateJob.new.perform(client: client)

      assert_includes client.cancelled_ids, "sub_asaas_001"
    end

    test "logs subscription.expired BillingEvent with correct reason" do
      assert_difference -> { Billing::BillingEvent.where(event_type: "subscription.expired").count } do
        Billing::SyncSubscriptionStateJob.new.perform(client: FakeClient.new)
      end

      event = Billing::BillingEvent.where(event_type: "subscription.expired").last
      assert_equal "past_due_grace_exceeded", event.metadata["reason"]
    end

    test "does NOT expire past_due subscription still within 30-day grace period" do
      @subscription.update!(current_period_end: 20.days.ago)

      Billing::SyncSubscriptionStateJob.new.perform(client: FakeClient.new)

      assert @subscription.reload.past_due?
    end

    test "skips Asaas DELETE when asaas_subscription_id is nil" do
      @subscription.update_column(:asaas_subscription_id, nil)
      client = FakeClient.new

      Billing::SyncSubscriptionStateJob.new.perform(client: client)

      assert_empty client.cancelled_ids
      assert @subscription.reload.expired?
    end

    test "Asaas API error on cancel does not crash the job" do
      assert_nothing_raised do
        Billing::SyncSubscriptionStateJob.new.perform(
          client: FakeClient.new(raise_on_cancel: true)
        )
      end

      assert @subscription.reload.past_due?, "Subscription should remain past_due after API error"
    end

    test "grace period expiry is skipped for targeted subscription_id runs" do
      Billing::SyncSubscriptionStateJob.new.perform(
        subscription_id: @subscription.id,
        client:          FakeClient.new
      )

      assert @subscription.reload.past_due?, "Targeted runs should not trigger grace period expiry"
    end

    # ── Asaas remote sync (existing behaviour) ────────────────────────────────

    test "syncs active subscription to expired when Asaas reports EXPIRED" do
      @subscription.update!(status: :active)

      Billing::SyncSubscriptionStateJob.new.perform(
        subscription_id: @subscription.id,
        client:          FakeClient.new(remote_status: "EXPIRED")
      )

      assert @subscription.reload.expired?
    end

    test "logs subscription.synced BillingEvent on remote status change" do
      @subscription.update!(status: :active)

      assert_difference -> { Billing::BillingEvent.where(event_type: "subscription.synced").count } do
        Billing::SyncSubscriptionStateJob.new.perform(
          subscription_id: @subscription.id,
          client:          FakeClient.new(remote_status: "INACTIVE")
        )
      end
    end

    test "does not log BillingEvent when remote status matches local" do
      @subscription.update!(status: :active)

      assert_no_difference "Billing::BillingEvent.count" do
        Billing::SyncSubscriptionStateJob.new.perform(
          subscription_id: @subscription.id,
          client:          FakeClient.new(remote_status: "ACTIVE")
        )
      end
    end

    test "Asaas API error on find_subscription does not crash the job" do
      assert_nothing_raised do
        Billing::SyncSubscriptionStateJob.new.perform(
          subscription_id: @subscription.id,
          client:          FakeClient.new(raise_on_find: true)
        )
      end
    end
  end
end
