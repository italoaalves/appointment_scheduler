# frozen_string_literal: true

class Space < ApplicationRecord
  include Schedulable

  attribute :timezone, :string, default: "America/Sao_Paulo"

  belongs_to :owner, class_name: "User", optional: true
  has_many :users, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :scheduling_links, dependent: :destroy
  has_one :personalized_scheduling_link, dependent: :destroy

  # business_hours: cached display string; updated by AvailabilitySchedule callback. Read-only.

  # Returns array of weekday integers (0=Sunday..6=Saturday) when the space has availability.
  def business_weekdays
    if availability_schedule.present?
      availability_schedule.availability_windows
        .where.not(opens_at: nil)
        .where.not(closes_at: nil)
        .distinct
        .pluck(:weekday)
    else
      legacy_business_schedule.keys.map(&:to_i)
    end
  end

  DEFAULT_BUSINESS_HOURS = {
    "1" => { "open" => "09:00", "close" => "17:00" },
    "2" => { "open" => "09:00", "close" => "17:00" },
    "3" => { "open" => "09:00", "close" => "17:00" },
    "4" => { "open" => "09:00", "close" => "17:00" },
    "5" => { "open" => "09:00", "close" => "17:00" }
  }.freeze
end
