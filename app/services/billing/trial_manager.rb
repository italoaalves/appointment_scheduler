# frozen_string_literal: true

module Billing
  class TrialManager
    TRIAL_DURATION = 14.days

    def self.start_trial(space)
      new.start_trial(space)
    end

    def self.expire_trial(subscription)
      new.expire_trial(subscription)
    end

    def start_trial(space)
      existing = Billing::Subscription
                   .where(space_id: space.id)
                   .where.not(status: Billing::Subscription.statuses[:expired])
                   .first
      return existing if existing

      now        = Time.current
      trial_ends = now + TRIAL_DURATION
      plan       = Billing::Plan.trial_plan

      subscription = Billing::Subscription.create!(
        space_id:             space.id,
        billing_plan:         plan,
        status:               :trialing,
        trial_ends_at:        trial_ends,
        current_period_start: now,
        current_period_end:   trial_ends
      )

      Billing::MessageCredit.create!(
        space_id:                space.id,
        balance:                 0,
        monthly_quota_remaining: plan.whatsapp_monthly_quota,
        quota_refreshed_at:      now
      )

      Billing::BillingEvent.create!(
        space_id:        space.id,
        subscription_id: subscription.id,
        event_type:      "subscription.created",
        metadata:        { plan_id: plan.slug, trial_ends_at: trial_ends.iso8601 }
      )

      subscription
    end

    def expire_trial(subscription)
      return false unless subscription.trialing?
      return false unless subscription.trial_ends_at.present? &&
                          subscription.trial_ends_at <= Time.current

      subscription.update!(status: :expired)

      Billing::BillingEvent.create!(
        space_id:        subscription.space_id,
        subscription_id: subscription.id,
        event_type:      "trial.expired",
        metadata:        { expired_at: Time.current.iso8601 }
      )

      true
    end
  end
end
