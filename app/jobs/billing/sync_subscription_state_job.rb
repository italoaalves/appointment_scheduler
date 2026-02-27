# frozen_string_literal: true

module Billing
  class SyncSubscriptionStateJob < ApplicationJob
    queue_as :default

    STATUS_MAP = {
      "ACTIVE"   => "active",
      "INACTIVE" => "canceled",
      "EXPIRED"  => "expired"
    }.freeze

    def perform(subscription_id: nil)
      subscriptions = if subscription_id
        Billing::Subscription.where(id: subscription_id)
      else
        Billing::Subscription
          .where.not(asaas_subscription_id: nil)
          .where(status: [ :active, :past_due ])
      end

      client = Billing::AsaasClient.new

      subscriptions.find_each do |subscription|
        remote = client.find_subscription(subscription.asaas_subscription_id)
        reconcile(subscription, remote)
      rescue Billing::AsaasClient::ApiError => e
        Rails.logger.warn(
          "[Billing] sync_failed subscription_id=#{subscription.id} error=#{e.message}"
        )
      end
    end

    private

    def reconcile(subscription, remote)
      remote_status = STATUS_MAP[remote["status"]]
      return unless remote_status
      return if subscription.status == remote_status

      previous_status = subscription.status
      subscription.update!(status: remote_status)

      Billing::BillingEvent.create!(
        space:        subscription.space,
        subscription: subscription,
        event_type:   "subscription.synced",
        metadata:     { previous_status: previous_status, new_status: remote_status }
      )
    end
  end
end
