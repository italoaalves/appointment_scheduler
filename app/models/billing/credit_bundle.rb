# frozen_string_literal: true

module Billing
  class CreditBundle < ApplicationRecord
    self.table_name = "credit_bundles"

    validates :name,        presence: true
    validates :amount,      presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :price_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }

    scope :available, -> { where(active: true).order(:position) }
  end
end
