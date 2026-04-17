# frozen_string_literal: true

class AppointmentReminder < ApplicationRecord
  include SpaceScoped

  LIVE_STATUSES = %w[scheduled queued sent delivered].freeze

  belongs_to :space
  belongs_to :appointment

  enum :status, {
    scheduled: 0,
    queued: 1,
    sent: 2,
    delivered: 3,
    failed: 4,
    superseded: 5
  }

  enum :channel, { whatsapp: "whatsapp", email: "email" }, suffix: :channel

  validates :kind, :fire_at, presence: true
  validates :kind, uniqueness: {
    scope: :appointment_id,
    conditions: -> { where(status: LIVE_STATUSES) }
  }

  scope :due, ->(cutoff = Time.current) { scheduled.where("fire_at <= ?", cutoff) }
  scope :live, -> { where(status: LIVE_STATUSES) }
end
