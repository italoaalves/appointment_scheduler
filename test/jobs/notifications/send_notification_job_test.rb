# frozen_string_literal: true

require "test_helper"

module Notifications
  class SendNotificationJobTest < ActiveJob::TestCase
    setup do
      ActionMailer::Base.deliveries.clear
      @appointment = appointments(:one)
      @appointment.update!(customer: customers(:one), scheduled_at: 2.days.from_now)
      spaces(:one).update!(owner_id: users(:manager).id) unless spaces(:one).owner_id.present?
    end

    test "enqueues appointment_booked notification" do
      assert_enqueued_with(job: SendNotificationJob) do
        SendNotificationJob.perform_later(event: :appointment_booked, appointment_id: @appointment.id)
      end
    end

    test "performs appointment_booked and sends email to owner and customer" do
      assert_difference "Notification.count", 1 do
        SendNotificationJob.perform_now(event: :appointment_booked, appointment_id: @appointment.id)
      end

      assert_equal 2, ActionMailer::Base.deliveries.size
      recipients = ActionMailer::Base.deliveries.flat_map(&:to)
      assert_includes recipients, users(:manager).email
      assert_includes recipients, customers(:one).email
    end

    test "performs appointment_confirmed and sends email" do
      SendNotificationJob.perform_now(event: :appointment_confirmed, appointment_id: @appointment.id)

      assert_equal 1, ActionMailer::Base.deliveries.size
      assert_equal [ customers(:one).email ], ActionMailer::Base.deliveries.first.to
    end

    test "discards when appointment not found" do
      assert_nothing_raised do
        SendNotificationJob.perform_now(event: :appointment_booked, appointment_id: 999_999)
      end
    end

    test "skips when appointment has no customer for customer events" do
      @appointment.update_column(:customer_id, nil)

      assert_nothing_raised do
        SendNotificationJob.perform_now(event: :appointment_confirmed, appointment_id: @appointment.id)
      end

      assert_equal 0, ActionMailer::Base.deliveries.size
    end
  end
end
