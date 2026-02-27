# frozen_string_literal: true

module Billing
  class Subscription < ApplicationRecord
    self.table_name = "subscriptions"

    include SpaceScoped

    belongs_to :space
    belongs_to :billing_plan,         class_name: "Billing::Plan"
    belongs_to :pending_billing_plan, class_name: "Billing::Plan", optional: true
    has_many :payments,       class_name: "Billing::Payment",      dependent: :destroy
    has_many :billing_events, class_name: "Billing::BillingEvent", dependent: :destroy

    enum :status, { trialing: 0, active: 1, past_due: 2, canceled: 3, expired: 4 }
    enum :payment_method, { pix: 0, credit_card: 1, boleto: 2 }, prefix: true

    validates :space_id, presence: true

    # Convenience alias — callers throughout the app use subscription.plan
    def plan
      billing_plan
    end
  end
end
