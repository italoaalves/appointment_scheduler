# frozen_string_literal: true

require "test_helper"

class Scheduling::Commands::RequestRescheduleTest < ActiveSupport::TestCase
  setup do
    @space = spaces(:one)
    @other_space = spaces(:two)
    @customer = customers(:one)
    @actor = users(:manager)
  end

  teardown do
    AppointmentEvent.where("idempotency_key LIKE ?", "test-scheduling-request-reschedule-%").delete_all
  end

  test "marks the appointment as rescheduled_by_customer and escalates the inbox conversation with a booking link" do
    appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now)
    personalized_link = PersonalizedSchedulingLink.create!(space: @space, slug: "reschedule-studio")
    conversations(:needs_reply_one).update!(customer: customers(:two))
    conversation = conversations(:open_with_messages)
    conversation.update!(customer: @customer, contact_identifier: @customer.phone, contact_name: @customer.name)

    travel_to Time.zone.parse("2026-04-17 14:20:00") do
      result = Scheduling::Commands::RequestReschedule.call(
        space: @space,
        appointment_id: appointment.id,
        actor: @actor,
        idempotency_key: "test-scheduling-request-reschedule-success",
        metadata: { via: "keyword", reason: "customer_request" }
      )

      assert_predicate result, :ok?
      assert_equal appointment, result.appointment

      appointment.reload
      conversation.reload
      event = AppointmentEvent.find(result.event_id)

      assert appointment.confirmation_rescheduled_by_customer?
      assert_equal Time.current, appointment.confirmation_decided_at
      assert_equal "keyword", appointment.confirmation_decided_via
      assert appointment.confirmed?

      assert conversation.needs_reply?
      assert_equal appointment.id, conversation.metadata["appointment_id"]
      assert_equal "reschedule_requested", conversation.metadata["reason"]
      assert_equal Rails.application.routes.url_helpers.book_by_slug_path(slug: personalized_link.slug),
                   conversation.metadata["booking_url"]

      assert_equal "appointment.reschedule_requested", event.event_type
      assert_equal({ "via" => "keyword", "reason" => "customer_request" }, event.metadata)
    end
  end

  test "creates a needs_reply conversation when none exists for the customer" do
    customer = @space.customers.create!(
      name: "Fresh Customer",
      phone: "+5511999990111",
      email: "fresh@example.com",
      address: "Rua Nova, 10"
    )
    appointment = create_appointment(status: :pending, scheduled_at: 2.days.from_now, customer: customer)
    scheduling_link = SchedulingLink.create!(space: @space, link_type: :permanent)

    assert_difference("Conversation.count", 1) do
      result = Scheduling::Commands::RequestReschedule.call(
        space: @space,
        appointment_id: appointment.id,
        actor: @actor,
        idempotency_key: "test-scheduling-request-reschedule-create-conversation"
      )

      assert_predicate result, :ok?
    end

    conversation = Conversation.order(:id).last

    assert_equal @space, conversation.space
    assert_equal customer, conversation.customer
    assert_equal customer.phone, conversation.contact_identifier
    assert_equal customer.name, conversation.contact_name
    assert conversation.whatsapp?
    assert conversation.needs_reply?
    assert_equal Rails.application.routes.url_helpers.book_path(token: scheduling_link.token),
                 conversation.metadata["booking_url"]
  end

  test "returns already_cancelled when the appointment is already cancelled" do
    appointment = create_appointment(status: :cancelled, scheduled_at: 2.days.from_now)

    result = Scheduling::Commands::RequestReschedule.call(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-request-reschedule-already-cancelled"
    )

    assert_not result.ok?
    assert_equal :already_cancelled, result.error
    assert_equal appointment, result.appointment
    assert_equal 0, AppointmentEvent.where(idempotency_key: "test-scheduling-request-reschedule-already-cancelled").count
  end

  test "returns already_finished when the appointment is already finished" do
    appointment = create_appointment(status: :finished, scheduled_at: 2.hours.ago)

    result = Scheduling::Commands::RequestReschedule.call(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-request-reschedule-already-finished"
    )

    assert_not result.ok?
    assert_equal :already_finished, result.error
    assert_equal appointment, result.appointment
    assert_equal 0, AppointmentEvent.where(idempotency_key: "test-scheduling-request-reschedule-already-finished").count
  end

  test "returns appointment_not_found for an appointment outside the given space" do
    appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now)

    result = Scheduling::Commands::RequestReschedule.call(
      space: @other_space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-request-reschedule-not-found"
    )

    assert_not result.ok?
    assert_equal :appointment_not_found, result.error
    assert_nil result.appointment
  end

  private

  def create_appointment(status:, scheduled_at:, customer: @customer)
    @space.appointments.create!(
      customer: customer,
      scheduled_at: scheduled_at,
      status: status,
      duration_minutes: 30,
      confirmation_state: :awaiting_customer
    )
  end
end
