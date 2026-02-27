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
    end
  end
end
