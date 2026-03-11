# frozen_string_literal: true

require "test_helper"

module Billing
  class ApplyDowngradeJobTest < ActiveJob::TestCase
    class FakeClient
      attr_reader :update_calls

      def initialize(raise_for: nil, status_code: 500)
        @update_calls = []
        @raise_for    = raise_for
        @status_code  = status_code
      end

      def update_subscription(id, attrs)
        raise Billing::AsaasClient::ApiError.new(@status_code, "fail") if @raise_for == id

        @update_calls << { id: id, attrs: attrs }
      end
    end

    setup do
      @space = Space.create!(name: "Downgrade Job Space #{SecureRandom.hex(4)}", timezone: "UTC")
      Billing::TrialManager.start_trial(@space)
      @subscription = @space.reload.subscription
      @subscription.update!(
        status:                :active,
        asaas_subscription_id: "sub_asaas_001",
        billing_plan:          billing_plans(:pro),
        pending_billing_plan:  billing_plans(:essential),
        current_period_end:    2.days.ago
      )
    end

    # ── Happy path ────────────────────────────────────────────────────────────

    test "applies pending downgrade when period has ended" do
      Billing::ApplyDowngradeJob.new.perform(client: FakeClient.new)

      @subscription.reload
      assert_equal "essential", @subscription.billing_plan.slug
      assert_nil @subscription.pending_billing_plan_id
    end

    test "calls Asaas update_subscription with new plan price" do
      client = FakeClient.new

      Billing::ApplyDowngradeJob.new.perform(client: client)

      assert_equal 1, client.update_calls.size
      call = client.update_calls.first
      assert_equal "sub_asaas_001", call[:id]
      assert_equal billing_plans(:essential).price_cents / 100.0, call[:attrs][:value]
    end

    test "logs a plan.changed BillingEvent with from/to and applied_by" do
      assert_difference -> { Billing::BillingEvent.where(event_type: "plan.changed").count } do
        Billing::ApplyDowngradeJob.new.perform(client: FakeClient.new)
      end

      event = Billing::BillingEvent.where(event_type: "plan.changed").last
      assert_equal "pro",           event.metadata["from"]
      assert_equal "essential",     event.metadata["to"]
      assert_equal "downgrade_job", event.metadata["applied_by"]
    end

    test "skips Asaas call when asaas_subscription_id is nil" do
      @subscription.update_column(:asaas_subscription_id, nil)
      client = FakeClient.new

      Billing::ApplyDowngradeJob.new.perform(client: client)

      assert_empty client.update_calls
      # plan still applied locally
      assert_equal "essential", @subscription.reload.billing_plan.slug
    end

    # ── Idempotency ───────────────────────────────────────────────────────────

    test "is idempotent: second run is a no-op after downgrade applied" do
      Billing::ApplyDowngradeJob.new.perform(client: FakeClient.new)

      assert_no_difference "Billing::BillingEvent.count" do
        Billing::ApplyDowngradeJob.new.perform(client: FakeClient.new)
      end
    end

    # ── Filtering ─────────────────────────────────────────────────────────────

    test "ignores subscriptions still within their paid period" do
      @subscription.update!(current_period_end: 5.days.from_now)
      client = FakeClient.new

      Billing::ApplyDowngradeJob.new.perform(client: client)

      assert_empty client.update_calls
      assert @subscription.reload.pending_billing_plan.present?
    end

    test "ignores subscriptions without a pending plan" do
      @subscription.update!(pending_billing_plan: nil)
      client = FakeClient.new

      Billing::ApplyDowngradeJob.new.perform(client: client)

      assert_empty client.update_calls
    end

    test "ignores canceled and expired subscriptions" do
      @subscription.update!(status: :canceled)
      client = FakeClient.new

      Billing::ApplyDowngradeJob.new.perform(client: client)

      assert_empty client.update_calls
      assert @subscription.reload.pending_billing_plan.present?
    end

    # ── Error handling ────────────────────────────────────────────────────────

    test "re-raises non-404 ApiErrors so Solid Queue can retry the job" do
      client = FakeClient.new(raise_for: "sub_asaas_001", status_code: 500)

      assert_raises(Billing::AsaasClient::ApiError) do
        Billing::ApplyDowngradeJob.new.perform(client: client)
      end

      @subscription.reload
      assert_equal "pro", @subscription.billing_plan.slug,      "Plan should be unchanged pending retry"
      assert_not_nil @subscription.pending_billing_plan_id,     "Pending plan should remain set"
    end

    test "treats Asaas 404 as success and applies the downgrade locally" do
      # Asaas returns 404 when the subscription was already deleted remotely
      client = FakeClient.new(raise_for: "sub_asaas_001", status_code: 404)

      assert_nothing_raised { Billing::ApplyDowngradeJob.new.perform(client: client) }

      @subscription.reload
      assert_equal "essential", @subscription.billing_plan.slug, "Plan should be downgraded locally"
      assert_nil @subscription.pending_billing_plan_id,          "Pending plan should be cleared"
    end

    test "treats Asaas 404 as success and still logs plan.changed BillingEvent" do
      client = FakeClient.new(raise_for: "sub_asaas_001", status_code: 404)

      assert_difference -> { Billing::BillingEvent.where(event_type: "plan.changed").count } do
        Billing::ApplyDowngradeJob.new.perform(client: client)
      end
    end
  end
end
