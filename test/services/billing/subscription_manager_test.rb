# frozen_string_literal: true

require "test_helper"

module Billing
  class SubscriptionManagerTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    # ── Helpers ───────────────────────────────────────────────────────────────

    # A simple fake AsaasClient that returns controlled responses or raises.
    class FakeAsaasClient
      attr_reader :calls, :call_args

      def initialize(responses = {})
        @responses = responses
        @calls     = []
        @call_args = {}
      end

      def create_subscription(**kwargs)
        record_call(:create_subscription, kwargs)
        response_for(:create_subscription) || { "id" => "sub_asaas_001" }
      end

      def update_subscription(id, attrs)
        record_call(:update_subscription, { id: id, attrs: attrs })
        response_for(:update_subscription) || { "id" => "sub_asaas_001" }
      end

      def cancel_subscription(id)
        record_call(:cancel_subscription, { id: id })
        response_for(:cancel_subscription) || { "deleted" => true }
      end

      private

      def record_call(method, args = {})
        @calls << method
        @call_args[method] = args
      end

      def response_for(method)
        val = @responses[method]
        raise val if val.is_a?(Exception)

        val
      end
    end

    def fake_client(responses = {})
      FakeAsaasClient.new(responses)
    end

    setup do
      @space = Space.create!(name: "Manager Test Space #{SecureRandom.hex(4)}", timezone: "UTC")
      Billing::TrialManager.start_trial(@space)
      @subscription = @space.reload.subscription
    end

    # ── subscribe ─────────────────────────────────────────────────────────────

    test "subscribe sets status to active and clears trial_ends_at" do
      @subscription.update_column(:trial_ends_at, 14.days.from_now)

      Billing::SubscriptionManager.subscribe(
        space:             @space,
        billing_plan_id:   billing_plans(:pro).id,
        payment_method:    :pix,
        asaas_customer_id: "cus_001",
        asaas_client:      fake_client
      )

      @subscription.reload
      assert @subscription.active?
      assert_nil @subscription.trial_ends_at
    end

    test "subscribe calls Asaas and updates local subscription" do
      client = fake_client

      result = Billing::SubscriptionManager.subscribe(
        space:             @space,
        billing_plan_id:   billing_plans(:pro).id,
        payment_method:    :pix,
        asaas_customer_id: "cus_001",
        asaas_client:      client
      )

      assert result[:success]
      assert_includes client.calls, :create_subscription

      @subscription.reload
      assert_equal "cus_001",       @subscription.asaas_customer_id
      assert_equal "sub_asaas_001", @subscription.asaas_subscription_id
      assert_equal "pro",           @subscription.billing_plan.slug
    end

    test "subscribe sets current_period_end to 1 month from now" do
      freeze_time do
        Billing::SubscriptionManager.subscribe(
          space:             @space,
          billing_plan_id:   billing_plans(:pro).id,
          payment_method:    :pix,
          asaas_customer_id: "cus_001",
          asaas_client:      fake_client
        )

        @subscription.reload
        assert_in_delta 1.month.from_now.to_i, @subscription.current_period_end.to_i, 2
      end
    end

    test "subscribe logs subscription.activated BillingEvent with plan_slug" do
      assert_difference -> { Billing::BillingEvent.where(event_type: "subscription.activated").count } do
        Billing::SubscriptionManager.subscribe(
          space:             @space,
          billing_plan_id:   billing_plans(:pro).id,
          payment_method:    :pix,
          asaas_customer_id: "cus_001",
          asaas_client:      fake_client
        )
      end

      event = Billing::BillingEvent.where(event_type: "subscription.activated").last
      assert_equal "pro", event.metadata["plan_slug"]
    end

    test "subscribe returns error hash when Asaas API fails" do
      error_client = fake_client(
        create_subscription: Billing::AsaasClient::ApiError.new(422, '{"errors":[]}')
      )

      result = Billing::SubscriptionManager.subscribe(
        space:             @space,
        billing_plan_id:   billing_plans(:pro).id,
        payment_method:    :pix,
        asaas_customer_id: "cus_001",
        asaas_client:      error_client
      )

      assert_equal false, result[:success]
      assert result[:error].present?
    end

    test "subscribe does not update local subscription when Asaas fails" do
      original_plan_id = @subscription.billing_plan_id
      error_client     = fake_client(
        create_subscription: Billing::AsaasClient::ApiError.new(500, "Server error")
      )

      Billing::SubscriptionManager.subscribe(
        space:             @space,
        billing_plan_id:   billing_plans(:pro).id,
        payment_method:    :pix,
        asaas_customer_id: "cus_001",
        asaas_client:      error_client
      )

      assert_equal original_plan_id, @subscription.reload.billing_plan_id
    end

    test "subscribe returns error when payment method not allowed for plan" do
      result = Billing::SubscriptionManager.subscribe(
        space:             @space,
        billing_plan_id:   billing_plans(:enterprise).id,
        payment_method:    :pix,
        asaas_customer_id: "cus_001",
        asaas_client:      fake_client
      )

      assert_equal false, result[:success]
      assert result[:error].present?
    end

    test "subscribe succeeds for enterprise with credit_card payment method" do
      result = Billing::SubscriptionManager.subscribe(
        space:             @space,
        billing_plan_id:   billing_plans(:enterprise).id,
        payment_method:    :credit_card,
        asaas_customer_id: "cus_001",
        asaas_client:      fake_client
      )

      assert result[:success]
    end

    test "subscribe raises RecordNotFound for invalid billing_plan_id" do
      assert_raises(ActiveRecord::RecordNotFound) do
        Billing::SubscriptionManager.subscribe(
          space:             @space,
          billing_plan_id:   0,
          payment_method:    :pix,
          asaas_customer_id: "cus_001",
          asaas_client:      fake_client
        )
      end
    end

    # ── upgrade ───────────────────────────────────────────────────────────────

    test "upgrade changes billing_plan immediately" do
      result = Billing::SubscriptionManager.upgrade(
        subscription:       @subscription,
        new_billing_plan_id: billing_plans(:enterprise).id,
        asaas_client:       fake_client
      )

      assert result[:success]
      assert_equal "enterprise", @subscription.reload.billing_plan.slug
    end

    test "upgrade clears pending_billing_plan" do
      @subscription.update_column(:pending_billing_plan_id, billing_plans(:essential).id)

      Billing::SubscriptionManager.upgrade(
        subscription:       @subscription,
        new_billing_plan_id: billing_plans(:enterprise).id,
        asaas_client:       fake_client
      )

      assert_nil @subscription.reload.pending_billing_plan_id
    end

    test "upgrade logs plan.changed BillingEvent with from/to slugs" do
      assert_difference -> { Billing::BillingEvent.where(event_type: "plan.changed").count } do
        Billing::SubscriptionManager.upgrade(
          subscription:       @subscription,
          new_billing_plan_id: billing_plans(:enterprise).id,
          asaas_client:       fake_client
        )
      end

      event = Billing::BillingEvent.where(event_type: "plan.changed").last
      assert_equal "enterprise", event.metadata["to"]
      assert_equal "pro",        event.metadata["from"]
    end

    test "upgrade returns error hash when Asaas fails" do
      @subscription.update_column(:asaas_subscription_id, "sub_asaas_001")

      error_client = fake_client(
        update_subscription: Billing::AsaasClient::ApiError.new(422, "error")
      )

      result = Billing::SubscriptionManager.upgrade(
        subscription:       @subscription,
        new_billing_plan_id: billing_plans(:enterprise).id,
        asaas_client:       error_client
      )

      assert_equal false, result[:success]
    end

    test "upgrade passes updatePendingPayments: true to Asaas" do
      @subscription.update_column(:asaas_subscription_id, "sub_asaas_001")
      client = fake_client

      Billing::SubscriptionManager.upgrade(
        subscription:        @subscription,
        new_billing_plan_id: billing_plans(:enterprise).id,
        asaas_client:        client
      )

      attrs = client.call_args[:update_subscription][:attrs]
      assert_equal true, attrs[:updatePendingPayments]
    end

    test "upgrade sends new plan price to Asaas" do
      @subscription.update_column(:asaas_subscription_id, "sub_asaas_001")
      client      = fake_client
      enterprise  = billing_plans(:enterprise)

      Billing::SubscriptionManager.upgrade(
        subscription:        @subscription,
        new_billing_plan_id: enterprise.id,
        asaas_client:        client
      )

      attrs = client.call_args[:update_subscription][:attrs]
      assert_equal enterprise.price_cents / 100.0, attrs[:value]
    end

    test "upgrade does not update local record when Asaas fails" do
      @subscription.update_column(:asaas_subscription_id, "sub_asaas_001")
      original_plan_id = @subscription.billing_plan_id

      error_client = fake_client(
        update_subscription: Billing::AsaasClient::ApiError.new(500, "error")
      )

      Billing::SubscriptionManager.upgrade(
        subscription:       @subscription,
        new_billing_plan_id: billing_plans(:enterprise).id,
        asaas_client:       error_client
      )

      assert_equal original_plan_id, @subscription.reload.billing_plan_id
    end

    test "upgrade with PIX enqueues PlanChangePaymentReminderJob" do
      @subscription.update_column(:payment_method, Billing::Subscription.payment_methods[:pix])

      assert_enqueued_with(job: Billing::PlanChangePaymentReminderJob) do
        Billing::SubscriptionManager.upgrade(
          subscription:        @subscription,
          new_billing_plan_id: billing_plans(:enterprise).id,
          asaas_client:        fake_client
        )
      end
    end

    test "upgrade with Boleto enqueues PlanChangePaymentReminderJob" do
      @subscription.update_column(:payment_method, Billing::Subscription.payment_methods[:boleto])

      assert_enqueued_with(job: Billing::PlanChangePaymentReminderJob) do
        Billing::SubscriptionManager.upgrade(
          subscription:        @subscription,
          new_billing_plan_id: billing_plans(:enterprise).id,
          asaas_client:        fake_client
        )
      end
    end

    test "upgrade with credit card does NOT enqueue PlanChangePaymentReminderJob" do
      @subscription.update_column(:payment_method, Billing::Subscription.payment_methods[:credit_card])

      assert_no_enqueued_jobs(only: Billing::PlanChangePaymentReminderJob) do
        Billing::SubscriptionManager.upgrade(
          subscription:        @subscription,
          new_billing_plan_id: billing_plans(:enterprise).id,
          asaas_client:        fake_client
        )
      end
    end

    test "upgrade with payment_method sends billingType to Asaas when method changes" do
      @subscription.update_columns(asaas_subscription_id: "sub_asaas_pm01", payment_method: :pix)
      client = fake_client

      Billing::SubscriptionManager.upgrade(
        subscription:        @subscription,
        new_billing_plan_id: billing_plans(:enterprise).id,
        payment_method:      :credit_card,
        asaas_client:        client
      )

      attrs = client.call_args[:update_subscription][:attrs]
      assert_equal "CREDIT_CARD", attrs[:billingType]
    end

    test "upgrade with payment_method updates local payment_method" do
      @subscription.update_columns(asaas_subscription_id: "sub_asaas_pm02", payment_method: :pix)

      Billing::SubscriptionManager.upgrade(
        subscription:        @subscription,
        new_billing_plan_id: billing_plans(:enterprise).id,
        payment_method:      :credit_card,
        asaas_client:        fake_client
      )

      assert @subscription.reload.payment_method_credit_card?
    end

    test "upgrade without payment_method keeps current payment_method" do
      @subscription.update_columns(asaas_subscription_id: "sub_asaas_pm03", payment_method: :pix)

      Billing::SubscriptionManager.upgrade(
        subscription:        @subscription,
        new_billing_plan_id: billing_plans(:enterprise).id,
        asaas_client:        fake_client
      )

      assert @subscription.reload.payment_method_pix?
    end

    test "upgrade with same payment_method does not include billingType in Asaas call" do
      @subscription.update_columns(asaas_subscription_id: "sub_asaas_pm04", payment_method: :pix)
      client = fake_client

      Billing::SubscriptionManager.upgrade(
        subscription:        @subscription,
        new_billing_plan_id: billing_plans(:enterprise).id,
        payment_method:      :pix,
        asaas_client:        client
      )

      attrs = client.call_args[:update_subscription][:attrs]
      assert_nil attrs[:billingType]
    end

    # ── downgrade ─────────────────────────────────────────────────────────────

    test "downgrade sets pending_billing_plan without changing current billing_plan" do
      result = Billing::SubscriptionManager.downgrade(
        subscription:        @subscription,
        new_billing_plan_id: billing_plans(:essential).id
      )

      assert result[:success]
      @subscription.reload
      assert_equal "pro",       @subscription.billing_plan.slug
      assert_equal "essential", @subscription.pending_billing_plan.slug
    end

    test "downgrade logs plan.downgrade_scheduled BillingEvent" do
      assert_difference -> { Billing::BillingEvent.where(event_type: "plan.downgrade_scheduled").count } do
        Billing::SubscriptionManager.downgrade(
          subscription:        @subscription,
          new_billing_plan_id: billing_plans(:essential).id
        )
      end

      event = Billing::BillingEvent.where(event_type: "plan.downgrade_scheduled").last
      assert_equal "essential", event.metadata["to"]
      assert_equal "pro",       event.metadata["from"]
    end

    test "downgrade raises ActiveRecord::RecordNotFound for invalid new_billing_plan_id" do
      assert_raises(ActiveRecord::RecordNotFound) do
        Billing::SubscriptionManager.downgrade(
          subscription:        @subscription,
          new_billing_plan_id: 0
        )
      end
    end

    # ── cancel ────────────────────────────────────────────────────────────────

    # Trial path: immediate Asaas DELETE + expire
    test "cancel (trial) sets status to expired immediately" do
      freeze_time do
        result = Billing::SubscriptionManager.cancel(
          subscription: @subscription,
          asaas_client: fake_client
        )

        assert result[:success]
        @subscription.reload
        assert @subscription.expired?
        assert_in_delta Time.current.to_i, @subscription.canceled_at.to_i, 2
      end
    end

    test "cancel (trial) calls Asaas DELETE when asaas_subscription_id present" do
      @subscription.update_column(:asaas_subscription_id, "sub_asaas_001")
      client = fake_client

      Billing::SubscriptionManager.cancel(
        subscription: @subscription,
        asaas_client: client
      )

      assert_includes client.calls, :cancel_subscription
    end

    test "cancel (trial) skips Asaas call when asaas_subscription_id is nil" do
      @subscription.update_column(:asaas_subscription_id, nil)
      client = fake_client

      Billing::SubscriptionManager.cancel(
        subscription: @subscription,
        asaas_client: client
      )

      assert_not_includes client.calls, :cancel_subscription
      assert @subscription.reload.expired?
    end

    # Paid path: deferred — no Asaas DELETE, status = canceled
    test "cancel (paid) sets status to canceled and records canceled_at" do
      @subscription.update_column(:status, :active)

      freeze_time do
        result = Billing::SubscriptionManager.cancel(
          subscription: @subscription,
          asaas_client: fake_client
        )

        assert result[:success]
        @subscription.reload
        assert @subscription.canceled?
        assert_in_delta Time.current.to_i, @subscription.canceled_at.to_i, 2
      end
    end

    test "cancel (paid) does NOT call Asaas DELETE" do
      @subscription.update_column(:status, :active)
      @subscription.update_column(:asaas_subscription_id, "sub_asaas_001")
      client = fake_client

      Billing::SubscriptionManager.cancel(
        subscription: @subscription,
        asaas_client: client
      )

      assert_not_includes client.calls, :cancel_subscription
      assert @subscription.reload.canceled?
    end

    # BillingEvent
    test "cancel logs subscription.canceled BillingEvent" do
      assert_difference -> { Billing::BillingEvent.where(event_type: "subscription.canceled").count } do
        Billing::SubscriptionManager.cancel(
          subscription: @subscription,
          asaas_client: fake_client
        )
      end
    end

    test "cancel BillingEvent has deferred: false for trial cancellation" do
      Billing::SubscriptionManager.cancel(
        subscription: @subscription,
        asaas_client: fake_client
      )

      event = Billing::BillingEvent.where(event_type: "subscription.canceled").last
      assert_equal false, event.metadata["deferred"]
    end

    test "cancel BillingEvent has deferred: true for paid cancellation" do
      @subscription.update_column(:status, :active)

      Billing::SubscriptionManager.cancel(
        subscription: @subscription,
        asaas_client: fake_client
      )

      event = Billing::BillingEvent.where(event_type: "subscription.canceled").last
      assert_equal true, event.metadata["deferred"]
    end

    test "cancel returns error hash when Asaas fails on trial" do
      @subscription.update_column(:asaas_subscription_id, "sub_asaas_001")

      error_client = fake_client(
        cancel_subscription: Billing::AsaasClient::ApiError.new(500, "error")
      )

      result = Billing::SubscriptionManager.cancel(
        subscription: @subscription,
        asaas_client: error_client
      )

      assert_equal false, result[:success]
      assert @subscription.reload.trialing?
    end

    # ── reactivate ────────────────────────────────────────────────────────────

    test "reactivate sets status to active and clears canceled_at" do
      @subscription.update!(status: :canceled, canceled_at: 1.day.ago,
                             current_period_end: 10.days.from_now,
                             asaas_subscription_id: "sub_reactivate_001")

      freeze_time do
        result = Billing::SubscriptionManager.reactivate(subscription: @subscription)

        assert result[:success]
        @subscription.reload
        assert @subscription.active?
        assert_nil @subscription.canceled_at
      end
    end

    test "reactivate logs a subscription.reactivated BillingEvent" do
      @subscription.update!(status: :canceled, canceled_at: 1.day.ago,
                             current_period_end: 10.days.from_now,
                             asaas_subscription_id: "sub_reactivate_002")

      assert_difference -> { Billing::BillingEvent.where(event_type: "subscription.reactivated").count } do
        Billing::SubscriptionManager.reactivate(subscription: @subscription)
      end
    end

    test "reactivate fails when subscription is expired" do
      @subscription.update!(status: :expired, canceled_at: 2.days.ago,
                             current_period_end: 1.day.ago)

      result = Billing::SubscriptionManager.reactivate(subscription: @subscription)

      assert_equal false, result[:success]
      assert result[:error].present?
      assert @subscription.reload.expired?
    end

    test "reactivate fails when current_period_end has already passed" do
      @subscription.update!(status: :canceled, canceled_at: 5.days.ago,
                             current_period_end: 1.day.ago)

      result = Billing::SubscriptionManager.reactivate(subscription: @subscription)

      assert_equal false, result[:success]
      assert @subscription.reload.canceled?
    end

    test "reactivate fails when current_period_end is nil" do
      @subscription.update!(status: :canceled, canceled_at: 1.day.ago,
                             current_period_end: nil)

      result = Billing::SubscriptionManager.reactivate(subscription: @subscription)

      assert_equal false, result[:success]
      assert @subscription.reload.canceled?
    end

    test "reactivate fails when asaas_subscription_id is blank" do
      @subscription.update!(status: :canceled, canceled_at: 1.day.ago,
                             current_period_end: 10.days.from_now,
                             asaas_subscription_id: nil)

      result = Billing::SubscriptionManager.reactivate(subscription: @subscription)

      assert_equal false, result[:success]
      assert result[:error].present?
      assert @subscription.reload.canceled?
    end
  end
end
