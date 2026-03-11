# frozen_string_literal: true

require "test_helper"

module Billing
  class ProcessCancellationJobTest < ActiveJob::TestCase
    # Minimal fake — records which IDs were cancelled; can raise for specific IDs.
    class FakeClient
      attr_reader :cancelled_ids

      def initialize(raise_for: nil, status_code: 500)
        @cancelled_ids = []
        @raise_for     = raise_for
        @status_code   = status_code
      end

      def cancel_subscription(id)
        raise Billing::AsaasClient::ApiError.new(@status_code, "fail") if @raise_for == id

        @cancelled_ids << id
      end
    end

    setup do
      @space = Space.create!(name: "CancelJob Space #{SecureRandom.hex(4)}", timezone: "UTC")
      Billing::TrialManager.start_trial(@space)
      @subscription = @space.reload.subscription
      @subscription.update!(
        status:                :canceled,
        asaas_subscription_id: "sub_asaas_001",
        current_period_end:    2.days.ago
      )
    end

    # ── Happy path ────────────────────────────────────────────────────────────

    test "calls Asaas DELETE and transitions subscription to expired" do
      client = FakeClient.new

      Billing::ProcessCancellationJob.new.perform(client: client)

      assert_includes client.cancelled_ids, "sub_asaas_001"
      assert @subscription.reload.expired?
    end

    test "logs a subscription.expired BillingEvent" do
      assert_difference -> { Billing::BillingEvent.where(event_type: "subscription.expired").count } do
        Billing::ProcessCancellationJob.new.perform(client: FakeClient.new)
      end

      event = Billing::BillingEvent.where(event_type: "subscription.expired").last
      assert_equal "cancellation_period_ended", event.metadata["reason"]
    end

    # ── Idempotency ───────────────────────────────────────────────────────────

    test "is idempotent: second run skips already-expired subscription" do
      Billing::ProcessCancellationJob.new.perform(client: FakeClient.new)

      # subscription is now expired — the query won't pick it up again
      assert_no_difference "Billing::BillingEvent.count" do
        Billing::ProcessCancellationJob.new.perform(client: FakeClient.new)
      end
    end

    # ── Filtering ─────────────────────────────────────────────────────────────

    test "skips canceled subscriptions without asaas_subscription_id" do
      @subscription.update!(asaas_subscription_id: nil)
      client = FakeClient.new

      Billing::ProcessCancellationJob.new.perform(client: client)

      assert_empty client.cancelled_ids
      assert @subscription.reload.canceled?, "Subscription should remain canceled"
    end

    test "skips canceled subscriptions still within their paid period" do
      @subscription.update!(current_period_end: 5.days.from_now)
      client = FakeClient.new

      Billing::ProcessCancellationJob.new.perform(client: client)

      assert_empty client.cancelled_ids
      assert @subscription.reload.canceled?
    end

    test "ignores non-canceled subscriptions" do
      @subscription.update!(status: :active)
      client = FakeClient.new

      Billing::ProcessCancellationJob.new.perform(client: client)

      assert_empty client.cancelled_ids
      assert @subscription.reload.active?
    end

    # ── Error handling ────────────────────────────────────────────────────────

    test "re-raises non-404 ApiErrors so Solid Queue can retry the job" do
      client = FakeClient.new(raise_for: "sub_asaas_001", status_code: 500)

      assert_raises(Billing::AsaasClient::ApiError) do
        Billing::ProcessCancellationJob.new.perform(client: client)
      end

      assert @subscription.reload.canceled?, "Subscription should remain canceled pending retry"
    end

    test "treats Asaas 404 as success and expires the subscription" do
      # Asaas returns 404 when the subscription was already deleted remotely
      client = FakeClient.new(raise_for: "sub_asaas_001", status_code: 404)

      assert_nothing_raised { Billing::ProcessCancellationJob.new.perform(client: client) }

      assert @subscription.reload.expired?, "Subscription should expire when Asaas returns 404"
    end

    test "treats Asaas 404 as success and still logs subscription.expired BillingEvent" do
      client = FakeClient.new(raise_for: "sub_asaas_001", status_code: 404)

      assert_difference -> { Billing::BillingEvent.where(event_type: "subscription.expired").count } do
        Billing::ProcessCancellationJob.new.perform(client: client)
      end
    end
  end
end
