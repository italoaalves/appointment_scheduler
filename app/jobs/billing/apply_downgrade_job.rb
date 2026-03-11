# frozen_string_literal: true

module Billing
  class ApplyDowngradeJob < ApplicationJob
    queue_as :default
    retry_on Billing::AsaasClient::ApiError, wait: :polynomially_longer, attempts: 5

    def perform(client: Billing::AsaasClient.new)
      Billing::Subscription
        .where.not(pending_billing_plan_id: nil)
        .where("current_period_end <= ?", Time.current)
        .where(status: [ :active, :past_due ])
        .includes(:billing_plan, :pending_billing_plan)
        .find_each do |subscription|
          apply(subscription, client)
        end
    end

    private

    def apply(subscription, client)
      new_plan      = subscription.pending_billing_plan
      old_plan_slug = subscription.billing_plan.slug

      if subscription.asaas_subscription_id.present?
        begin
          client.update_subscription(
            subscription.asaas_subscription_id,
            { value: new_plan.price_cents / 100.0 }
          )
        rescue Billing::AsaasClient::ApiError => e
          raise unless e.status_code == 404  # Subscription deleted on Asaas — skip remote update
        end
      end

      ActiveRecord::Base.transaction do
        subscription.update!(
          billing_plan:         new_plan,
          pending_billing_plan: nil
        )

        Billing::BillingEvent.create!(
          space_id:        subscription.space_id,
          subscription_id: subscription.id,
          event_type:      "plan.changed",
          metadata:        { from: old_plan_slug, to: new_plan.slug, applied_by: "downgrade_job" }
        )
      end
    end
  end
end
