# frozen_string_literal: true

module Schedulable
  extend ActiveSupport::Concern

  included do
    has_one :availability_schedule, as: :schedulable, dependent: :destroy
    accepts_nested_attributes_for :availability_schedule, allow_destroy: true
  end

  def windows_for_date(date)
    availability_schedule&.windows_for_date(date) || []
  end

  def available_slots(from_date:, to_date:, limit: 50)
    Spaces::SlotAvailabilityService.call(schedulable: self, from_date: from_date, to_date: to_date, limit: limit)
  end

  def empty_slots_count(from_date:, to_date:)
    available_slots(from_date: from_date, to_date: to_date, limit: 2000).size
  end

  def effective_timezone
    (availability_schedule&.timezone.presence || try(:timezone)).to_s
  end
end
