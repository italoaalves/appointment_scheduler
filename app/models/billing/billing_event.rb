# frozen_string_literal: true

module Billing
  class BillingEvent < ApplicationRecord
    self.table_name = "billing_events"

    include SpaceScoped

    belongs_to :space
    belongs_to :subscription, class_name: "Billing::Subscription", optional: true

    validates :event_type, presence: true

    def readonly?
      persisted?
    end
  end
end
