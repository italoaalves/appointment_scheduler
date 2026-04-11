# frozen_string_literal: true

module Billing
  class SubscriptionMailer < ApplicationMailer
    def plan_change_payment_reminder(subscription:, new_plan:)
      @subscription   = subscription
      @new_plan       = new_plan
      @space          = subscription.space
      @payment_method = subscription.payment_method
      recipient       = @space.owner

      with_mail_locale(recipient:, fallback_space: @space) do
        mail(
          to:      recipient.email,
          subject: I18n.t(
            "billing.subscription_mailer.plan_change_payment_reminder.subject",
            plan_name: new_plan.name
          )
        )
      end
    end
  end
end
