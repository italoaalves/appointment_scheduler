# frozen_string_literal: true

module Billing
  class SubscriptionManager
    def self.subscribe(space:, billing_plan_id:, payment_method:, asaas_customer_id:,
                       asaas_client: Billing::AsaasClient.new)
      new(asaas_client).subscribe(space: space, billing_plan_id: billing_plan_id,
                                   payment_method: payment_method,
                                   asaas_customer_id: asaas_customer_id)
    end

    def self.upgrade(subscription:, new_billing_plan_id:, payment_method: nil,
                     asaas_client: Billing::AsaasClient.new)
      new(asaas_client).upgrade(subscription: subscription, new_billing_plan_id: new_billing_plan_id,
                                payment_method: payment_method)
    end

    def self.downgrade(subscription:, new_billing_plan_id:)
      new(nil).downgrade(subscription: subscription, new_billing_plan_id: new_billing_plan_id)
    end

    def self.cancel(subscription:, asaas_client: Billing::AsaasClient.new)
      new(asaas_client).cancel(subscription: subscription)
    end

    def self.reactivate(subscription:)
      new(nil).reactivate(subscription: subscription)
    end

    # ── Instance ─────────────────────────────────────────────────────────────

    def initialize(asaas_client)
      @client = asaas_client
    end

    def subscribe(space:, billing_plan_id:, payment_method:, asaas_customer_id:)
      plan = Billing::Plan.active.find(billing_plan_id)

      unless plan.requires_payment_method?(payment_method)
        return { success: false, error: I18n.t("billing.checkout.payment_method_not_allowed") }
      end

      asaas_result = @client.create_subscription(
        customer_id:        asaas_customer_id,
        billing_type:       payment_method.to_sym,
        value:              plan.price_cents / 100.0,
        next_due_date:      Date.current.to_s,
        description:        plan.name,
        external_reference: "space_#{space.id}"
      )
      asaas_subscription_id = asaas_result["id"]

      subscription = nil

      ActiveRecord::Base.transaction do
        subscription = find_or_initialize_subscription(space)
        subscription.assign_attributes(
          billing_plan:          plan,
          status:                :active,
          payment_method:        payment_method,
          asaas_subscription_id: asaas_subscription_id,
          asaas_customer_id:     asaas_customer_id,
          current_period_start:  Time.current,
          current_period_end:    1.month.from_now,
          trial_ends_at:         nil
        )
        subscription.save!

        Billing::BillingEvent.create!(
          space_id:        space.id,
          subscription_id: subscription.id,
          event_type:      "subscription.activated",
          metadata:        { plan_slug: plan.slug, payment_method: payment_method.to_s }
        )
      end

      { success: true, subscription: subscription }
    rescue Billing::AsaasClient::ApiError => e
      Rails.logger.error("[Billing::SubscriptionManager] Asaas API error during subscribe: #{e.message}")
      { success: false, error: I18n.t("billing.generic_error") }
    end

    def upgrade(subscription:, new_billing_plan_id:, payment_method: nil)
      old_plan_slug = subscription.billing_plan.slug
      new_plan      = Billing::Plan.active.find(new_billing_plan_id)

      if subscription.asaas_subscription_id.present?
        attrs = { value: new_plan.price_cents / 100.0, updatePendingPayments: true }

        if payment_method.present? && payment_method.to_s != subscription.payment_method
          attrs[:billingType] = Billing::AsaasClient::BILLING_TYPES[payment_method.to_sym]
        end

        @client.update_subscription(subscription.asaas_subscription_id, attrs)
      end

      ActiveRecord::Base.transaction do
        update_attrs = { billing_plan: new_plan, pending_billing_plan: nil }
        update_attrs[:payment_method] = payment_method if payment_method.present?
        subscription.update!(update_attrs)

        Billing::BillingEvent.create!(
          space_id:        subscription.space_id,
          subscription_id: subscription.id,
          event_type:      "plan.changed",
          metadata:        { from: old_plan_slug, to: new_plan.slug }
        )
      end

      if subscription.payment_method_pix? || subscription.payment_method_boleto?
        Billing::PlanChangePaymentReminderJob.perform_later(subscription.id, new_plan.id)
      end

      { success: true }
    rescue Billing::AsaasClient::ApiError => e
      Rails.logger.error("[Billing::SubscriptionManager] Asaas API error during upgrade: #{e.message}")
      { success: false, error: I18n.t("billing.generic_error") }
    end

    def downgrade(subscription:, new_billing_plan_id:)
      new_plan = Billing::Plan.active.find(new_billing_plan_id)

      ActiveRecord::Base.transaction do
        subscription.update!(pending_billing_plan: new_plan)

        Billing::BillingEvent.create!(
          space_id:        subscription.space_id,
          subscription_id: subscription.id,
          event_type:      "plan.downgrade_scheduled",
          metadata:        {
            from:         subscription.billing_plan.slug,
            to:           new_plan.slug,
            effective_at: subscription.current_period_end&.iso8601
          }
        )
      end

      { success: true }
    rescue Billing::AsaasClient::ApiError => e
      Rails.logger.error("[Billing::SubscriptionManager] Asaas API error during downgrade: #{e.message}")
      { success: false, error: I18n.t("billing.generic_error") }
    end

    def cancel(subscription:)
      ActiveRecord::Base.transaction do
        if subscription.trialing?
          # Trial: no payment was made — delete from Asaas immediately and expire.
          if subscription.asaas_subscription_id.present?
            @client.cancel_subscription(subscription.asaas_subscription_id)
          end
          subscription.update!(status: :expired, canceled_at: Time.current)
        else
          # Paid: customer has paid for the current period — defer Asaas deletion.
          # Access continues until current_period_end. A separate job handles
          # the actual Asaas DELETE once the period ends (task 39).
          subscription.update!(status: :canceled, canceled_at: Time.current)
        end

        Billing::BillingEvent.create!(
          space_id:        subscription.space_id,
          subscription_id: subscription.id,
          event_type:      "subscription.canceled",
          metadata:        {
            canceled_at: Time.current.iso8601,
            deferred:    !subscription.expired?
          }
        )
      end

      { success: true }
    rescue Billing::AsaasClient::ApiError => e
      Rails.logger.error("[Billing::SubscriptionManager] Asaas API error during cancel: #{e.message}")
      { success: false, error: I18n.t("billing.generic_error") }
    end

    def reactivate(subscription:)
      unless subscription.canceled? && subscription.current_period_end&.future?
        return { success: false, error: I18n.t("billing.resubscribe_unavailable") }
      end

      # Safety: if the Asaas subscription was already deleted (e.g., SUBSCRIPTION_DELETED
      # webhook received before the customer reactivated), reactivation is impossible —
      # there is no active Asaas subscription to generate future charges.
      if subscription.asaas_subscription_id.blank?
        return { success: false, error: I18n.t("billing.resubscribe_unavailable") }
      end

      ActiveRecord::Base.transaction do
        subscription.update!(status: :active, canceled_at: nil)

        Billing::BillingEvent.create!(
          space_id:        subscription.space_id,
          subscription_id: subscription.id,
          event_type:      "subscription.reactivated",
          metadata:        { reactivated_at: Time.current.iso8601 }
        )
      end

      { success: true }
    end

    private

    def find_or_initialize_subscription(space)
      Billing::Subscription
        .where(space_id: space.id)
        .order(created_at: :desc)
        .first_or_initialize(space_id: space.id, status: :trialing)
    end
  end
end
