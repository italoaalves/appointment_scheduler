# frozen_string_literal: true

class Space < ApplicationRecord
  include Schedulable

  attribute :timezone, :string, default: "America/Sao_Paulo"

  belongs_to :owner, class_name: "User", optional: true
  has_many :space_memberships, dependent: :destroy
  has_many :users, through: :space_memberships

  validates :name, presence: true
  validates :slot_duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :timezone, presence: true
  has_many :customers, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :scheduling_links, dependent: :destroy
  has_one :personalized_scheduling_link, dependent: :destroy

  has_one  :subscription,    class_name: "Billing::Subscription",  dependent: :destroy
  has_one  :message_credit,  class_name: "Billing::MessageCredit", dependent: :destroy
  has_many :payments,        class_name: "Billing::Payment",       dependent: :destroy
  has_many :billing_events,  class_name: "Billing::BillingEvent",  dependent: :destroy

  # business_hours: cached display string; updated by AvailabilitySchedule callback. Read-only.

  def availability_configured?
    availability_schedule.present? &&
      availability_schedule.availability_windows.where.not(opens_at: nil).where.not(closes_at: nil).exists?
  end

  def setup_complete?
    availability_configured? && scheduling_links.any?
  end

  def onboarding_complete?
    completed_onboarding_at.present?
  end

  # Returns array of weekday integers (0=Sunday..6=Saturday) when the space has availability.
  def business_weekdays
    return [] unless availability_schedule

    availability_schedule
      .availability_windows
      .where.not(opens_at: nil)
      .where.not(closes_at: nil)
      .distinct
      .pluck(:weekday)
  end

  DEFAULT_BUSINESS_HOURS = {
    "1" => { "open" => "09:00", "close" => "17:00" },
    "2" => { "open" => "09:00", "close" => "17:00" },
    "3" => { "open" => "09:00", "close" => "17:00" },
    "4" => { "open" => "09:00", "close" => "17:00" },
    "5" => { "open" => "09:00", "close" => "17:00" }
  }.freeze
end
