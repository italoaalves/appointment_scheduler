# frozen_string_literal: true

module Billing
  class CreditsLowCheckJob < ApplicationJob
    queue_as :default

    LOW_THRESHOLD = 10

    def perform
      Billing::MessageCredit
        .where("balance + monthly_quota_remaining <= ?", LOW_THRESHOLD)
        .where("balance + monthly_quota_remaining > 0")
        .find_each do |credit|
          space = credit.space
          owner = space.owner
          next if owner.nil?
          next if space.subscription&.plan&.whatsapp_unlimited?

          total = credit.balance + credit.monthly_quota_remaining

          Notifications::BillingNotifier.notify(
            event_type: :credits_low,
            user:       owner,
            notifiable: credit,
            params:     { count: total }
          )
        end
    end
  end
end
