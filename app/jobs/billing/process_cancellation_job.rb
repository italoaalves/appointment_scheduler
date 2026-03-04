# frozen_string_literal: true

module Billing
  class ProcessCancellationJob < ApplicationJob
    queue_as :default

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
      client.cancel_subscription(subscription.asaas_subscription_id)

      subscription.update!(status: :expired)

      Billing::BillingEvent.create!(
        space_id:        subscription.space_id,
        subscription_id: subscription.id,
        event_type:      "subscription.expired",
        metadata:        { reason: "cancellation_period_ended" }
      )
    rescue Billing::AsaasClient::ApiError => e
      Rails.logger.warn(
        "[ProcessCancellationJob] Asaas DELETE failed subscription_id=#{subscription.id}: #{e.message}"
      )
    end
  end
end
