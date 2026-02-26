# frozen_string_literal: true

module Spaces
  class AppointmentTransitionService
    PAST_REQUIRED_STATUSES = %i[no_show finished].freeze

    def self.call(appointment:, to_status:, finished_at_raw: nil, actor: nil)
      new(appointment: appointment, to_status: to_status.to_sym, finished_at_raw: finished_at_raw, actor: actor).call
    end

    def initialize(appointment:, to_status:, finished_at_raw: nil, actor: nil)
      @appointment = appointment
      @to_status = to_status.to_sym
      @finished_at_raw = finished_at_raw
      @actor = actor
    end

    def call
      return { success: false, error_key: :cancelled_locked } if @appointment.cancelled?
      return { success: false, error_key: :cannot_before_scheduled } if requires_past? && !@appointment.scheduled_in_past?
      return { success: false, error_key: :policy_cancellation_blocked } if cancelling? && !cancellation_allowed?

      attrs = { status: @to_status }
      attrs[:finished_at] = parse_finished_at if @to_status == :finished

      if @appointment.update(attrs)
        { success: true }
      else
        { success: false, errors: @appointment.errors.full_messages }
      end
    end

    private

    def cancelling?
      @to_status == :cancelled
    end

    def cancellation_allowed?
      SpacePolicyChecker.cancellation_allowed?(appointment: @appointment, actor: @actor)
    end

    def requires_past?
      PAST_REQUIRED_STATUSES.include?(@to_status)
    end

    def parse_finished_at
      return Time.current if @finished_at_raw.blank?

      tz = TimezoneResolver.zone(@appointment.space)
      tz.parse(@finished_at_raw.to_s)
    rescue ArgumentError
      Time.current
    end
  end
end
