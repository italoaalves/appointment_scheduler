# frozen_string_literal: true

module Billing
  class ProcessCancellationJob < ApplicationJob
    queue_as :default
    retry_on Billing::AsaasClient::ApiError, wait: :polynomially_longer, attempts: 5, report: true

    def perform(client: Billing::AsaasClient.new)
      Billing::Subscription
        .where(status: :canceled)
        .where("current_period_end <= ?", Time.current)
        .where.not(asaas_subscription_id: nil)
        .find_each do |subscription|
          process(subscription, client)
        end
    end

    private

    def process(subscription, client)
      begin
        client.cancel_subscription(subscription.asaas_subscription_id)
      rescue Billing::AsaasClient::ApiError => e
        raise unless e.status_code == 404  # Already deleted on Asaas — safe to proceed
      end

      subscription.update!(status: :expired)

      Billing::BillingEvent.create!(
        space_id:        subscription.space_id,
        subscription_id: subscription.id,
        event_type:      "subscription.expired",
        metadata:        { reason: "cancellation_period_ended" }
      )
    end
  end
end
