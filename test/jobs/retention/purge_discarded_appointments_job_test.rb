# frozen_string_literal: true

require "test_helper"

module Retention
  class PurgeDiscardedAppointmentsJobTest < ActiveJob::TestCase
    test "purges eligible discarded appointments" do
      appointment = Appointment.create!(
        space: spaces(:one),
        customer: customers(:one),
        scheduled_at: 40.days.ago,
        status: :cancelled,
        duration_minutes: 30,
        requested_at: 41.days.ago
      )
      appointment.update_column(:discarded_at, 31.days.ago)

      assert_difference -> { Appointment.unscoped.count } => -1 do
        PurgeDiscardedAppointmentsJob.perform_now
      end

      assert_nil Appointment.unscoped.find_by(id: appointment.id)
    end

    test "is idempotent when no appointments remain to purge" do
      PurgeDiscardedAppointmentsJob.perform_now

      assert_no_difference -> { Appointment.unscoped.count } do
        PurgeDiscardedAppointmentsJob.perform_now
      end
    end
  end
end
