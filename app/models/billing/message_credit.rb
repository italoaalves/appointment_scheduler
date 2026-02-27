# frozen_string_literal: true

module Billing
  class MessageCredit < ApplicationRecord
    self.table_name = "message_credits"

    include SpaceScoped

    belongs_to :space

    validates :space_id,               uniqueness: true
    validates :balance,                numericality: { greater_than_or_equal_to: 0 }
    validates :monthly_quota_remaining, numericality: { greater_than_or_equal_to: 0 }
  end
end
