# frozen_string_literal: true

require "test_helper"

class Scheduling::Commands::CancelAppointmentTest < ActiveSupport::TestCase
  setup do
    @space = spaces(:one)
    @other_space = spaces(:two)
    @customer = customers(:one)
    @actor = users(:manager)
  end

  teardown do
    AppointmentEvent.where("idempotency_key LIKE ?", "test-scheduling-cancel-%").delete_all
  end

  test "cancels an appointment and writes an event with metadata" do
    appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now)

    travel_to Time.zone.parse("2026-04-17 11:15:00") do
      result = Scheduling::Commands::CancelAppointment.call(
        space: @space,
        appointment_id: appointment.id,
        actor: @actor,
        idempotency_key: "test-scheduling-cancel-success",
        metadata: { via: "inbox", reason: "customer_request" }
      )

      assert_predicate result, :ok?
      assert_equal appointment, result.appointment

      appointment.reload
      event = AppointmentEvent.find(result.event_id)

      assert appointment.cancelled?
      assert appointment.confirmation_declined_by_customer?
      assert_equal Time.current, appointment.confirmation_decided_at
      assert_equal "inbox", appointment.confirmation_decided_via
      assert_equal "appointment.cancelled", event.event_type
      assert_equal({ "via" => "inbox", "reason" => "customer_request" }, event.metadata)
    end
  end

  test "replays the original successful result for the same idempotency key" do
    appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now)
    idempotency_key = "test-scheduling-cancel-replay"

    first = Scheduling::Commands::CancelAppointment.call(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: idempotency_key,
      metadata: { via: "button" }
    )

    second = Scheduling::Commands::CancelAppointment.call(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: idempotency_key,
      metadata: { via: "keyword" }
    )

    assert_equal 1, AppointmentEvent.where(idempotency_key: idempotency_key).count
    assert_predicate first, :ok?
    assert_predicate second, :ok?
    assert_equal first.event_id, second.event_id
    assert_equal appointment, second.appointment
  end

  test "returns already_cancelled when the appointment is already cancelled" do
    appointment = create_appointment(status: :cancelled, scheduled_at: 2.days.from_now)

    result = Scheduling::Commands::CancelAppointment.call(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-cancel-already-cancelled"
    )

    assert_not result.ok?
    assert_equal :already_cancelled, result.error
    assert_equal appointment, result.appointment
    assert_equal 0, AppointmentEvent.where(idempotency_key: "test-scheduling-cancel-already-cancelled").count
  end

  test "returns already_finished when the appointment is already finished" do
    appointment = create_appointment(status: :finished, scheduled_at: 2.hours.ago)

    result = Scheduling::Commands::CancelAppointment.call(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-cancel-finished"
    )

    assert_not result.ok?
    assert_equal :already_finished, result.error
    assert_equal appointment, result.appointment
    assert_equal 0, AppointmentEvent.where(idempotency_key: "test-scheduling-cancel-finished").count
  end

  test "returns appointment_not_found for an appointment outside the given space" do
    appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now)

    result = Scheduling::Commands::CancelAppointment.call(
      space: @other_space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-cancel-not-found"
    )

    assert_not result.ok?
    assert_equal :appointment_not_found, result.error
    assert_nil result.appointment
  end

  private

  def create_appointment(status:, scheduled_at:)
    @space.appointments.create!(
      customer: @customer,
      scheduled_at: scheduled_at,
      status: status,
      duration_minutes: 30,
      confirmation_state: :awaiting_customer
    )
  end
end
