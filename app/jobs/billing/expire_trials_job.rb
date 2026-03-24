# frozen_string_literal: true

module Billing
  class ExpireTrialsJob < ApplicationJob
    queue_as :default

    def perform
      Billing::Subscription
        .where(status: :trialing)
        .where("trial_ends_at <= ?", Time.current)
        .find_each do |subscription|
          Billing::TrialManager.expire_trial(subscription)
        end

      Billing::Subscription
        .where(status: :pending_payment)
        .where("created_at <= ?", 7.days.ago)
        .find_each do |subscription|
          subscription.update!(status: :expired, canceled_at: Time.current)
          Billing::BillingEvent.create!(
            space_id:        subscription.space_id,
            subscription_id: subscription.id,
            event_type:      "subscription.expired",
            metadata:        { reason: "pending_payment_timeout" }
          )
        end
    end
  end
end
