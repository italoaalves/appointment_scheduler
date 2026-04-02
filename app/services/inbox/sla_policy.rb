# frozen_string_literal: true

module Inbox
  class SlaPolicy
    THRESHOLDS = {
      urgent: 15.minutes,
      high:   1.hour,
      normal: 4.hours,
      low:    24.hours
    }.freeze

    # Compute the SLA deadline from a given start time.
    def self.deadline_for(priority, from: Time.current)
      duration = THRESHOLDS.fetch(priority.to_sym, THRESHOLDS[:normal])
      from + duration
    end

    # True if SLA is breached: no first response yet and deadline passed.
    def self.breached?(conversation)
      return false if conversation.first_response_at.present?
      return false if conversation.sla_deadline_at.blank?

      Time.current > conversation.sla_deadline_at
    end
  end
end
