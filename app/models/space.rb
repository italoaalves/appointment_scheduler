class Space < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :clients, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :scheduling_links, dependent: :destroy

  DEFAULT_BUSINESS_HOURS = {
    "1" => { "open" => "09:00", "close" => "17:00" },
    "2" => { "open" => "09:00", "close" => "17:00" },
    "3" => { "open" => "09:00", "close" => "17:00" },
    "4" => { "open" => "09:00", "close" => "17:00" },
    "5" => { "open" => "09:00", "close" => "17:00" }
  }.freeze

  def business_schedule
    return DEFAULT_BUSINESS_HOURS if business_hours_schedule.blank?

    business_hours_schedule
  end

  def available_slots(from_date:, to_date:, limit: 50)
    SlotAvailabilityService.call(space: self, from_date: from_date, to_date: to_date, limit: limit)
  end

  def empty_slots_count(from_date:, to_date:)
    available_slots(from_date: from_date, to_date: to_date, limit: 2000).size
  end
end

