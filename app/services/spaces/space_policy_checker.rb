# frozen_string_literal: true

module Spaces
  class SpacePolicyChecker
    def self.cancellation_allowed?(appointment:, actor: nil)
      new(appointment: appointment, actor: actor).cancellation_allowed?
    end

    def self.reschedule_allowed?(appointment:, actor: nil, from_scheduled_at: nil)
      new(appointment: appointment, actor: actor, from_scheduled_at: from_scheduled_at).reschedule_allowed?
    end

    def self.slot_requestable?(space:, scheduled_at:)
      new(space: space, scheduled_at: scheduled_at).slot_requestable?
    end

    def initialize(appointment: nil, actor: nil, space: nil, scheduled_at: nil, from_scheduled_at: nil)
      @appointment = appointment
      @actor = actor
      @space = appointment&.space || space
      @scheduled_at = scheduled_at
      @from_scheduled_at = from_scheduled_at
    end

    def cancellation_allowed?
      return true if actor_can_bypass?
      return true if @space.cancellation_min_hours_before.blank?

      threshold = @space.cancellation_min_hours_before.hours
      time_until_scheduled >= threshold
    end

    def reschedule_allowed?
      return true if actor_can_bypass?
      return true if @space.reschedule_min_hours_before.blank?

      reference_time = @from_scheduled_at.presence || @appointment&.scheduled_at
      return true if reference_time.blank?

      threshold = @space.reschedule_min_hours_before.hours
      (reference_time - Time.current) >= threshold
    end

    def slot_requestable?
      return true if @scheduled_at.blank?
      return true unless @space

      tz = TimezoneResolver.zone(@space)
      slot_time = @scheduled_at.in_time_zone(tz)
      now = Time.current.in_time_zone(tz)
      today = now.to_date

      if @space.request_max_days_ahead.present?
        max_date = today + @space.request_max_days_ahead.days
        return false if slot_time.to_date > max_date
      end

      if @space.request_min_hours_ahead.present?
        min_slot = now + @space.request_min_hours_ahead.hours
        return false if slot_time < min_slot
      end

      true
    end

    private

    def actor_can_bypass?
      @actor.present? && @space.present? && @actor.space_owner?(@space)
    end

    def time_until_scheduled
      return Float::INFINITY if @appointment.scheduled_at.blank?

      @appointment.scheduled_at - Time.current
    end
  end
end
