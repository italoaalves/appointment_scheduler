# frozen_string_literal: true

require "test_helper"

module Spaces
  class NotificationDispatcherTest < ActiveSupport::TestCase
    setup do
      ActionMailer::Base.deliveries.clear
      @space      = spaces(:one)
      @space.update!(owner_id: users(:manager).id) unless @space.owner_id.present?
      @customer   = customers(:one)
      @appointment = appointments(:one)
      @appointment.update!(customer: @customer, scheduled_at: 2.days.from_now)
    end

    # -------------------------------------------------------------------------
    # Email delivery (existing behaviour — must not regress)
    # -------------------------------------------------------------------------

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
      assert_equal I18n.t("notifications.appointment_confirmed.subject"), mail.subject
    end

    test "appointment_cancelled sends email to customer" do
      @appointment.update!(status: :cancelled)

      NotificationDispatcher.call(event: :appointment_cancelled, appointment: @appointment)

      assert_equal 1, ActionMailer::Base.deliveries.size
      mail = ActionMailer::Base.deliveries.first
      assert_equal [ @customer.email ], mail.to
      assert_equal I18n.t("notifications.appointment_cancelled.subject"), mail.subject
    end

    test "appointment_rescheduled sends email to customer" do
      @appointment.update!(status: :rescheduled)

      NotificationDispatcher.call(event: :appointment_rescheduled, appointment: @appointment)

      assert_equal 1, ActionMailer::Base.deliveries.size
      mail = ActionMailer::Base.deliveries.first
      assert_equal [ @customer.email ], mail.to
      assert_equal I18n.t("notifications.appointment_rescheduled.subject"), mail.subject
    end

    test "customer events skip when customer is blank" do
      @appointment.update_column(:customer_id, nil)

      NotificationDispatcher.call(event: :appointment_confirmed, appointment: @appointment)

      assert_equal 0, ActionMailer::Base.deliveries.size
    end

    # -------------------------------------------------------------------------
    # In-app Notification creation
    # -------------------------------------------------------------------------

    test "appointment_booked creates in-app notification for owner" do
      assert_difference "Notification.count", 1 do
        NotificationDispatcher.call(event: :appointment_booked, appointment: @appointment)
      end

      notif = Notification.last
      assert_equal @space.owner,       notif.user
      assert_equal @appointment,       notif.notifiable
      assert_equal "appointment_booked", notif.event_type
      assert_equal I18n.t("notifications.in_app.appointment_booked.title"), notif.title
      assert_includes notif.body, @customer.name
    end

    test "appointment_booked does not create notification when owner has no email (not dispatched)" do
      @space.owner.update_column(:email, "")
      @customer.update_column(:email, nil)

      assert_no_difference "Notification.count" do
        NotificationDispatcher.call(event: :appointment_booked, appointment: @appointment)
      end
    end

    test "appointment_confirmed creates notification for customer user when linked" do
      linked_user = users(:manager)
      @customer.update!(user: linked_user)
      @appointment.update!(status: :confirmed)

      assert_difference "Notification.count", 1 do
        NotificationDispatcher.call(event: :appointment_confirmed, appointment: @appointment)
      end

      notif = Notification.last
      assert_equal linked_user,          notif.user
      assert_equal @appointment,         notif.notifiable
      assert_equal "appointment_confirmed", notif.event_type
    end

    test "appointment_confirmed does not create notification when customer has no user" do
      assert_nil @customer.user
      @appointment.update!(status: :confirmed)

      assert_no_difference "Notification.count" do
        NotificationDispatcher.call(event: :appointment_confirmed, appointment: @appointment)
      end
    end

    test "appointment_cancelled creates notification for customer user when linked" do
      @customer.update!(user: users(:manager))
      @appointment.update!(status: :cancelled)

      assert_difference "Notification.count", 1 do
        NotificationDispatcher.call(event: :appointment_cancelled, appointment: @appointment)
      end
      assert_equal "appointment_cancelled", Notification.last.event_type
    end

    test "appointment_rescheduled creates notification for customer user when linked" do
      @customer.update!(user: users(:manager))
      @appointment.update!(status: :rescheduled)

      assert_difference "Notification.count", 1 do
        NotificationDispatcher.call(event: :appointment_rescheduled, appointment: @appointment)
      end
      assert_equal "appointment_rescheduled", Notification.last.event_type
    end

    # -------------------------------------------------------------------------
    # WhatsApp template building
    # -------------------------------------------------------------------------

    test "whatsapp dispatch uses correct template name per event" do
      @customer.update!(
        phone: "+5511999990099",
        whatsapp_opted_in_at: Time.current,
        whatsapp_opt_in_source: "staff_entry"
      )

      [ :appointment_confirmed, :appointment_cancelled, :appointment_rescheduled ].each do |event|
        received_template = nil
        fake_channel = Object.new
        fake_channel.define_singleton_method(:deliver) do |**kwargs|
          received_template = kwargs[:template]
          { success: true }
        end

        Billing::PlanEnforcer.stub(:can?, true) do
          Messaging::Channels::Whatsapp.stub(:new, fake_channel) do
            NotificationDispatcher.call(event: event, appointment: @appointment)
          end
        end

        assert_not_nil received_template, "Expected template for #{event}"
        assert_equal "appointment_#{event}_v1", received_template[:name]
        assert_equal "pt_BR", received_template[:language]
      end
    end

    test "whatsapp template components include customer name, date, and time" do
      @customer.update!(
        phone: "+5511999990099",
        name: "Maria Silva",
        whatsapp_opted_in_at: Time.current,
        whatsapp_opt_in_source: "staff_entry"
      )
      @appointment.update!(scheduled_at: Time.zone.parse("2026-06-15 14:30:00"))

      received_template = nil
      fake_channel = Object.new
      fake_channel.define_singleton_method(:deliver) do |**kwargs|
        received_template = kwargs[:template]
        { success: true }
      end

      Billing::PlanEnforcer.stub(:can?, true) do
        Messaging::Channels::Whatsapp.stub(:new, fake_channel) do
          NotificationDispatcher.call(event: :appointment_confirmed, appointment: @appointment)
        end
      end

      assert_not_nil received_template
      params = received_template[:components].first[:parameters]
      texts  = params.map { |p| p[:text] }
      assert_includes texts, "Maria Silva"
    end

    test "whatsapp delivery is skipped when customer has no consent" do
      @customer.update!(phone: "+5511999990099", email: nil)

      delivery_called = false
      fake_channel = Object.new
      fake_channel.define_singleton_method(:deliver) do |**|
        delivery_called = true
        { success: true }
      end

      Billing::PlanEnforcer.stub(:can?, true) do
        Messaging::Channels::Whatsapp.stub(:new, fake_channel) do
          NotificationDispatcher.call(event: :appointment_confirmed, appointment: @appointment)
        end
      end

      assert_not delivery_called
    end

    test "in-app failure does not block email delivery" do
      # Force Notification.create! to raise
      Notification.stub(:create!, ->(*) { raise ActiveRecord::RecordInvalid }) do
        assert_nothing_raised do
          NotificationDispatcher.call(event: :appointment_booked, appointment: @appointment)
        end
        # Email to owner still delivered
        assert ActionMailer::Base.deliveries.any?
      end
    end
  end
end
