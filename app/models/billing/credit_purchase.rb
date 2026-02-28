# frozen_string_literal: true

module Billing
  class CreditPurchase < ApplicationRecord
    include SpaceScoped

    self.table_name = "credit_purchases"

    belongs_to :space
    belongs_to :credit_bundle, class_name: "Billing::CreditBundle"
    belongs_to :actor, class_name: "User", optional: true

    enum :status, { pending: 0, completed: 1, failed: 2 }

    validates :space_id, :credit_bundle_id, :amount, :price_cents, presence: true
    validates :amount, numericality: { greater_than: 0 }
    validates :price_cents, numericality: { greater_than: 0 }
  end
end
