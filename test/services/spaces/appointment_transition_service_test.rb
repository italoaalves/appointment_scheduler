# frozen_string_literal: true

require "test_helper"

module Spaces
  class AppointmentTransitionServiceTest < ActiveSupport::TestCase
    setup do
      @space = spaces(:one)
      @customer = customers(:one)
      @manager = users(:manager)
    end

    test "confirms a pending appointment" do
      appointment = create_appointment(status: :pending, scheduled_at: 2.days.from_now)
      result = AppointmentTransitionService.call(appointment: appointment, to_status: :confirmed)
      assert result[:success]
      assert appointment.reload.confirmed?
    end

    test "cancels a confirmed appointment when policy allows" do
      appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now)
      result = AppointmentTransitionService.call(appointment: appointment, to_status: :cancelled, actor: @manager)
      assert result[:success]
      assert appointment.reload.cancelled?
    end

    test "rejects cancel on already cancelled appointment" do
      appointment = create_appointment(status: :cancelled, scheduled_at: 2.days.from_now)
      result = AppointmentTransitionService.call(appointment: appointment, to_status: :confirmed)
      assert_not result[:success]
      assert_equal :cancelled_locked, result[:error_key]
    end

    test "rejects no_show for future appointment" do
      appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now)
      result = AppointmentTransitionService.call(appointment: appointment, to_status: :no_show)
      assert_not result[:success]
      assert_equal :cannot_before_scheduled, result[:error_key]
    end

    test "marks no_show for past appointment" do
      appointment = create_appointment(status: :confirmed, scheduled_at: 2.hours.ago)
      result = AppointmentTransitionService.call(appointment: appointment, to_status: :no_show)
      assert result[:success]
      assert appointment.reload.no_show?
    end

    test "finishes a past appointment" do
      appointment = create_appointment(status: :confirmed, scheduled_at: 2.hours.ago)
      result = AppointmentTransitionService.call(appointment: appointment, to_status: :finished)
      assert result[:success]
      assert appointment.reload.finished?
      assert_not_nil appointment.finished_at
    end

    test "rejects finish for future appointment" do
      appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now)
      result = AppointmentTransitionService.call(appointment: appointment, to_status: :finished)
      assert_not result[:success]
      assert_equal :cannot_before_scheduled, result[:error_key]
    end

    test "cancellation blocked by policy" do
      @space.update!(cancellation_min_hours_before: 48)
      appointment = create_appointment(status: :confirmed, scheduled_at: 12.hours.from_now)
      result = AppointmentTransitionService.call(appointment: appointment, to_status: :cancelled, actor: nil)
      assert_not result[:success]
      assert_equal :policy_cancellation_blocked, result[:error_key]
    end

    private

    def create_appointment(status:, scheduled_at:)
      @space.appointments.create!(
        customer: @customer,
        scheduled_at: scheduled_at,
        status: status,
        duration_minutes: 30
      )
    end
  end
end
