# frozen_string_literal: true

module Billing
  class SyncSubscriptionStateJob < ApplicationJob
    queue_as :default

    STATUS_MAP = {
      "ACTIVE"   => "active",
      "INACTIVE" => "canceled",
      "EXPIRED"  => "expired"
    }.freeze

    GRACE_PERIOD = 30.days

    def perform(subscription_id: nil, client: Billing::AsaasClient.new)
      subscriptions = if subscription_id
        Billing::Subscription.where(id: subscription_id)
      else
        Billing::Subscription
          .where.not(asaas_subscription_id: nil)
          .where(status: [ :active, :past_due ])
      end

      subscriptions.find_each do |subscription|
        remote = client.find_subscription(subscription.asaas_subscription_id)
        reconcile(subscription, remote)
      rescue Billing::AsaasClient::ApiError => e
        Rails.logger.warn(
          "[Billing] sync_failed subscription_id=#{subscription.id} error=#{e.message}"
        )
      end

      expire_overdue_subscriptions(client) unless subscription_id
    end

    private

    def expire_overdue_subscriptions(client)
      Billing::Subscription
        .where(status: :past_due)
        .where("current_period_end < ?", GRACE_PERIOD.ago)
        .find_each do |subscription|
          expire(subscription, client)
        end
    end

    def expire(subscription, client)
      if subscription.asaas_subscription_id.present?
        client.cancel_subscription(subscription.asaas_subscription_id)
      end

      subscription.update!(status: :expired)

      Billing::BillingEvent.create!(
        space_id:        subscription.space_id,
        subscription_id: subscription.id,
        event_type:      "subscription.expired",
        metadata:        { reason: "past_due_grace_exceeded" }
      )
    rescue Billing::AsaasClient::ApiError => e
      Rails.logger.warn(
        "[SyncSubscriptionStateJob] expire failed subscription_id=#{subscription.id}: #{e.message}"
      )
    end

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
