# frozen_string_literal: true

module Billing
  class BillingEvent < ApplicationRecord
    self.table_name = "billing_events"

    include SpaceScoped

    belongs_to :space
    belongs_to :subscription, class_name: "Billing::Subscription", optional: true

    validates :event_type, presence: true

    before_update { raise ActiveRecord::ReadOnlyRecord, "#{self.class} is append-only and cannot be updated" }
  end
end
