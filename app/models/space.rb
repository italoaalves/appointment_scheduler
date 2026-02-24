# frozen_string_literal: true

class Space < ApplicationRecord
  include Schedulable

  attribute :timezone, :string, default: "America/Sao_Paulo"

  has_many :users, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :scheduling_links, dependent: :destroy
  has_one :personalized_scheduling_link, dependent: :destroy

  # business_hours: cached display string; updated by AvailabilitySchedule callback. Read-only.

  DEFAULT_BUSINESS_HOURS = {
    "1" => { "open" => "09:00", "close" => "17:00" },
    "2" => { "open" => "09:00", "close" => "17:00" },
    "3" => { "open" => "09:00", "close" => "17:00" },
    "4" => { "open" => "09:00", "close" => "17:00" },
    "5" => { "open" => "09:00", "close" => "17:00" }
  }.freeze
end
