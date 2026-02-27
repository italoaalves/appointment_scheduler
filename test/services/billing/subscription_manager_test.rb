# frozen_string_literal: true

require "test_helper"

module Billing
  class SubscriptionManagerTest < ActiveSupport::TestCase
    # ── Helpers ───────────────────────────────────────────────────────────────

    # A simple fake AsaasClient that returns controlled responses or raises.
    class FakeAsaasClient
      attr_reader :calls

      def initialize(responses = {})
        @responses = responses
        @calls     = []
      end

      def create_subscription(**_kwargs)
        record_call(:create_subscription)
        response_for(:create_subscription) || { "id" => "sub_asaas_001" }
      end

      def update_subscription(_id, _attrs)
        record_call(:update_subscription)
        response_for(:update_subscription) || { "id" => "sub_asaas_001" }
      end

      def cancel_subscription(_id)
        record_call(:cancel_subscription)
        response_for(:cancel_subscription) || { "deleted" => true }
      end

      private

      def record_call(method)
        @calls << method
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

    test "cancel sets status to canceled and records canceled_at" do
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

    test "cancel logs subscription.canceled BillingEvent" do
      assert_difference -> { Billing::BillingEvent.where(event_type: "subscription.canceled").count } do
        Billing::SubscriptionManager.cancel(
          subscription: @subscription,
          asaas_client: fake_client
        )
      end
    end

    test "cancel calls Asaas when asaas_subscription_id present" do
      @subscription.update_column(:asaas_subscription_id, "sub_asaas_001")
      client = fake_client

      Billing::SubscriptionManager.cancel(
        subscription: @subscription,
        asaas_client: client
      )

      assert_includes client.calls, :cancel_subscription
    end

    test "cancel skips Asaas call when asaas_subscription_id is nil" do
      @subscription.update_column(:asaas_subscription_id, nil)
      client = fake_client

      Billing::SubscriptionManager.cancel(
        subscription: @subscription,
        asaas_client: client
      )

      assert_not_includes client.calls, :cancel_subscription
      assert @subscription.reload.canceled?
    end

    test "cancel returns error hash when Asaas fails" do
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
  end
end
