# frozen_string_literal: true

module Billing
  class TrialEndingReminderJob < ApplicationJob
    queue_as :default

    REMINDER_WINDOW = 3.days

    def perform
      Billing::Subscription
        .where(status: :trialing)
        .where(trial_ends_at: Time.current..REMINDER_WINDOW.from_now)
        .find_each do |subscription|
          owner = subscription.space.owner
          next if owner.nil?

          days_left = ((subscription.trial_ends_at - Time.current) / 1.day).ceil

          Notifications::BillingNotifier.notify(
            event_type: :trial_ending,
            user:       owner,
            notifiable: subscription,
            params:     { days: days_left }
          )
        end
    end
  end
end
