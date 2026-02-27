# frozen_string_literal: true

module Billing
  class Payment < ApplicationRecord
    self.table_name = "payments"

    include SpaceScoped

    belongs_to :subscription, class_name: "Billing::Subscription"
    belongs_to :space

    enum :status,         { pending: 0, confirmed: 1, overdue: 2, refunded: 3, failed: 4 }
    enum :payment_method, { pix: 0, credit_card: 1, boleto: 2 }, prefix: true

    validates :asaas_payment_id, presence: true, uniqueness: true
    validates :amount_cents,     presence: true, numericality: { greater_than: 0 }
  end
end
