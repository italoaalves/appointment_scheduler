# frozen_string_literal: true

module Billing
  class Subscription < ApplicationRecord
    self.table_name = "subscriptions"

    include SpaceScoped

    belongs_to :space
    has_many :payments,       class_name: "Billing::Payment",      dependent: :destroy
    has_many :billing_events, class_name: "Billing::BillingEvent", dependent: :destroy

    enum :status, { trialing: 0, active: 1, past_due: 2, canceled: 3, expired: 4 }
    enum :payment_method, { pix: 0, credit_card: 1, boleto: 2 }, prefix: true

    validates :plan_id,   presence: true,
                          inclusion: { in: ->(_) { Billing::Plan.all.map(&:id) } }
    validates :space_id,  presence: true

    def plan
      Billing::Plan.find(plan_id)
    end
  end
end
