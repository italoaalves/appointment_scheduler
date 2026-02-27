# frozen_string_literal: true

module Billing
  class CreditBundle < ApplicationRecord
    self.table_name = "credit_bundles"

    validates :name,        presence: true
    validates :amount,      presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :price_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }

    scope :available, -> { where(active: true).order(:position) }

    # Backward-compatible shim — still used by CreditsController and CreditManager.
    # Remove in task 24.
    def self.bundles
      available.map { |b| OpenStruct.new(amount: b.amount, price_cents: b.price_cents) }.freeze
    end
  end
end
