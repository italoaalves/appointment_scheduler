# frozen_string_literal: true

require "test_helper"

module Spaces
  class NotificationDispatcherTest < ActiveSupport::TestCase
    setup do
      I18n.locale = :en
      ActionMailer::Base.deliveries.clear
      @space      = spaces(:one)
      @space.update!(owner_id: users(:manager).id) unless @space.owner_id.present?
      @customer   = customers(:one)
      @appointment = appointments(:one)
      @appointment.update!(customer: @customer, scheduled_at: 2.days.from_now)
    end

    test "appointment_booked sends email to space owner and customer" do
      assert @space.owner.present?, "Space must have owner for this test"
      assert @space.owner.email.present?, "Owner must have email"
      assert @customer.email.present?, "Customer must have email"

      NotificationDispatcher.call(event: :appointment_booked, appointment: @appointment)

      assert_equal 2, ActionMailer::Base.deliveries.size
      owner_mail = ActionMailer::Base.deliveries.find { |m| m.to.include?(@space.owner.email) }
      customer_mail = ActionMailer::Base.deliveries.find { |m| m.to.include?(@customer.email) }
      assert owner_mail.present?, "Owner should receive email"
      assert customer_mail.present?, "Customer should receive confirmation email"
      assert_includes owner_mail.subject, @customer.name
    end

    test "appointment_booked does nothing when owner and customer have no email" do
      @space.owner.update_column(:email, "")
      @customer.update_column(:email, nil)

      NotificationDispatcher.call(event: :appointment_booked, appointment: @appointment)

      assert_equal 0, ActionMailer::Base.deliveries.size
    end

    test "appointment_confirmed sends email to customer" do
      @appointment.update!(status: :confirmed)

      NotificationDispatcher.call(event: :appointment_confirmed, appointment: @appointment)

      assert_equal 1, ActionMailer::Base.deliveries.size
      mail = ActionMailer::Base.deliveries.first
      assert_equal [ @customer.email ], mail.to
      assert_includes mail.body.encoded, "confirmed"
    end

    test "appointment_cancelled sends email to customer" do
      @appointment.update!(status: :cancelled)

      NotificationDispatcher.call(event: :appointment_cancelled, appointment: @appointment)

      assert_equal 1, ActionMailer::Base.deliveries.size
      mail = ActionMailer::Base.deliveries.first
      assert_equal [ @customer.email ], mail.to
      assert_includes mail.body.encoded, "cancelled"
    end

    test "appointment_rescheduled sends email to customer" do
      @appointment.update!(status: :rescheduled)

      NotificationDispatcher.call(event: :appointment_rescheduled, appointment: @appointment)

      assert_equal 1, ActionMailer::Base.deliveries.size
      mail = ActionMailer::Base.deliveries.first
      assert_equal [ @customer.email ], mail.to
      assert_includes mail.body.encoded, "moved"
    end

    test "customer events skip when customer is blank" do
      @appointment.update_column(:customer_id, nil)

      NotificationDispatcher.call(event: :appointment_confirmed, appointment: @appointment)

      assert_equal 0, ActionMailer::Base.deliveries.size
    end
  end
end
