# frozen_string_literal: true

module Billing
  class SubscriptionManager
    def self.subscribe(space:, plan_id:, payment_method:, asaas_customer_id:,
                       asaas_client: Billing::AsaasClient.new)
      new(asaas_client).subscribe(space: space, plan_id: plan_id,
                                   payment_method: payment_method,
                                   asaas_customer_id: asaas_customer_id)
    end

    def self.upgrade(subscription:, new_plan_id:,
                     asaas_client: Billing::AsaasClient.new)
      new(asaas_client).upgrade(subscription: subscription, new_plan_id: new_plan_id)
    end

    def self.downgrade(subscription:, new_plan_id:)
      new(nil).downgrade(subscription: subscription, new_plan_id: new_plan_id)
    end

    def self.cancel(subscription:, asaas_client: Billing::AsaasClient.new)
      new(asaas_client).cancel(subscription: subscription)
    end

    # ── Instance ─────────────────────────────────────────────────────────────

    def initialize(asaas_client)
      @client = asaas_client
    end

    def subscribe(space:, plan_id:, payment_method:, asaas_customer_id:)
      plan = Billing::Plan.find(plan_id)

      asaas_subscription_id = nil

      unless plan.price_cents == 0
        asaas_result = @client.create_subscription(
          customer_id:        asaas_customer_id,
          billing_type:       payment_method.to_sym,
          value:              plan.price_cents / 100.0,
          next_due_date:      Date.current.to_s,
          description:        plan.name,
          external_reference: "space_#{space.id}"
        )
        asaas_subscription_id = asaas_result["id"]
      end

      subscription = nil

      ActiveRecord::Base.transaction do
        subscription = find_or_initialize_subscription(space)
        subscription.assign_attributes(
          plan_id:               plan_id,
          status:                :active,
          payment_method:        payment_method,
          asaas_subscription_id: asaas_subscription_id,
          asaas_customer_id:     asaas_customer_id,
          current_period_start:  Time.current,
          current_period_end:    30.days.from_now,
          trial_ends_at:         nil
        )
        subscription.save!

        Billing::BillingEvent.create!(
          space_id:        space.id,
          subscription_id: subscription.id,
          event_type:      "subscription.activated",
          metadata:        { plan_id: plan_id, payment_method: payment_method.to_s }
        )
      end

      { success: true, subscription: subscription }
    rescue Billing::AsaasClient::ApiError => e
      { success: false, error: e.message }
    end

    def upgrade(subscription:, new_plan_id:)
      old_plan_id = subscription.plan_id
      new_plan    = Billing::Plan.find(new_plan_id)

      if subscription.asaas_subscription_id.present?
        @client.update_subscription(
          subscription.asaas_subscription_id,
          { value: new_plan.price_cents / 100.0 }
        )
      end

      ActiveRecord::Base.transaction do
        subscription.update!(plan_id: new_plan_id, pending_plan_id: nil)

        Billing::BillingEvent.create!(
          space_id:        subscription.space_id,
          subscription_id: subscription.id,
          event_type:      "plan.changed",
          metadata:        { from: old_plan_id, to: new_plan_id }
        )
      end

      { success: true }
    rescue Billing::AsaasClient::ApiError => e
      { success: false, error: e.message }
    end

    def downgrade(subscription:, new_plan_id:)
      Billing::Plan.find(new_plan_id)

      ActiveRecord::Base.transaction do
        subscription.update!(pending_plan_id: new_plan_id)

        Billing::BillingEvent.create!(
          space_id:        subscription.space_id,
          subscription_id: subscription.id,
          event_type:      "plan.downgrade_scheduled",
          metadata:        {
            from:         subscription.plan_id,
            to:           new_plan_id,
            effective_at: subscription.current_period_end&.iso8601
          }
        )
      end

      { success: true }
    rescue Billing::AsaasClient::ApiError => e
      { success: false, error: e.message }
    end

    def cancel(subscription:)
      if subscription.asaas_subscription_id.present?
        @client.cancel_subscription(subscription.asaas_subscription_id)
      end

      ActiveRecord::Base.transaction do
        subscription.update!(status: :canceled, canceled_at: Time.current)

        Billing::BillingEvent.create!(
          space_id:        subscription.space_id,
          subscription_id: subscription.id,
          event_type:      "subscription.canceled",
          metadata:        { canceled_at: Time.current.iso8601 }
        )
      end

      { success: true }
    rescue Billing::AsaasClient::ApiError => e
      { success: false, error: e.message }
    end

    private

    def find_or_initialize_subscription(space)
      Billing::Subscription
        .where(space_id: space.id)
        .order(created_at: :desc)
        .first_or_initialize(space_id: space.id, plan_id: "starter", status: :trialing)
    end
  end
end
