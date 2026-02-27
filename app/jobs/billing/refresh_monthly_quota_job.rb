# frozen_string_literal: true

module Billing
  class RefreshMonthlyQuotaJob < ApplicationJob
    queue_as :default

    def perform
      Billing::Subscription.where(status: :active).find_each do |subscription|
        credit = subscription.space.message_credit
        next unless credit
        next if credit.quota_refreshed_at.present? &&
                credit.quota_refreshed_at >= subscription.current_period_start

        plan = subscription.plan
        credit.update!(
          monthly_quota_remaining: plan.whatsapp_monthly_quota,
          quota_refreshed_at:      Time.current
        )

        Billing::BillingEvent.create!(
          space:        subscription.space,
          subscription: subscription,
          event_type:   "credits.quota_refreshed",
          metadata:     { quota: plan.whatsapp_monthly_quota }
        )
      end
    end
  end
end
