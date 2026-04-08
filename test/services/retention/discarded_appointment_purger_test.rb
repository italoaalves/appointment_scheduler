# frozen_string_literal: true

require "test_helper"

module Retention
  class DiscardedAppointmentPurgerTest < ActiveSupport::TestCase
    setup do
      @old_appointment = Appointment.create!(
        space: spaces(:one),
        customer: customers(:one),
        scheduled_at: 35.days.ago,
        status: :cancelled,
        duration_minutes: 30,
        requested_at: 36.days.ago
      )
      @old_appointment.update_column(:discarded_at, 31.days.ago)
      @recent_appointment = Appointment.create!(
        space: spaces(:one),
        customer: customers(:two),
        scheduled_at: 5.days.ago,
        status: :cancelled,
        duration_minutes: 30,
        requested_at: 6.days.ago
      )
      @recent_appointment.update_column(:discarded_at, 5.days.ago)
      Message.create!(
        sender: users(:manager),
        recipient: users(:secretary),
        messageable: @old_appointment,
        content: "Old appointment message"
      )
      Notification.create!(
        user: users(:manager),
        title: "Old appointment removed",
        body: "Cleanup",
        event_type: "appointment_deleted",
        notifiable: @old_appointment
      )
    end

    test "hard deletes discarded appointments older than 30 days and related records" do
      assert_difference -> { Appointment.unscoped.count } => -1,
        -> { Message.count } => -1,
        -> { Notification.count } => -1 do
        assert_equal 1, DiscardedAppointmentPurger.call
      end

      assert_nil Appointment.unscoped.find_by(id: @old_appointment.id)
      assert_not_nil Appointment.unscoped.find_by(id: @recent_appointment.id)
    end

    test "is idempotent when nothing else is eligible" do
      DiscardedAppointmentPurger.call

      assert_no_difference -> { Appointment.unscoped.count } do
        assert_equal 0, DiscardedAppointmentPurger.call
      end
    end
  end
end
