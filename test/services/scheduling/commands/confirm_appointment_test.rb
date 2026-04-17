# frozen_string_literal: true

require "test_helper"

class Scheduling::Commands::ConfirmAppointmentTest < ActiveSupport::TestCase
  setup do
    @space = spaces(:one)
    @other_space = spaces(:two)
    @customer = customers(:one)
    @actor = users(:manager)
  end

  teardown do
    AppointmentEvent.where("idempotency_key LIKE ?", "test-scheduling-confirm-%").delete_all
  end

  test "confirms a pending appointment and writes an event with metadata" do
    appointment = create_appointment(status: :pending, scheduled_at: 2.days.from_now)

    travel_to Time.zone.parse("2026-04-17 10:30:00") do
      result = Scheduling::Commands::ConfirmAppointment.call(
        space: @space,
        appointment_id: appointment.id,
        actor: @actor,
        idempotency_key: "test-scheduling-confirm-success",
        metadata: { via: "button", reason: "customer_reply" }
      )

      assert_predicate result, :ok?
      assert_equal appointment, result.appointment

      appointment.reload
      event = AppointmentEvent.find(result.event_id)

      assert appointment.confirmed?
      assert appointment.confirmation_confirmed_by_customer?
      assert_equal Time.current, appointment.confirmation_decided_at
      assert_equal "button", appointment.confirmation_decided_via
      assert_equal "appointment.confirmed", event.event_type
      assert_equal({ "via" => "button", "reason" => "customer_reply" }, event.metadata)
    end
  end

  test "replays the original successful result for the same idempotency key" do
    appointment = create_appointment(status: :pending, scheduled_at: 2.days.from_now)
    idempotency_key = "test-scheduling-confirm-replay"

    first = Scheduling::Commands::ConfirmAppointment.call(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: idempotency_key,
      metadata: { via: "button" }
    )

    second = Scheduling::Commands::ConfirmAppointment.call(
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

  test "returns cancelled when the appointment is already cancelled" do
    appointment = create_appointment(status: :cancelled, scheduled_at: 2.days.from_now)

    result = Scheduling::Commands::ConfirmAppointment.call(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-confirm-cancelled"
    )

    assert_not result.ok?
    assert_equal :cancelled, result.error
    assert_equal appointment, result.appointment
    assert_equal 0, AppointmentEvent.where(idempotency_key: "test-scheduling-confirm-cancelled").count
  end

  test "returns already_finished when the appointment is already finished" do
    appointment = create_appointment(status: :finished, scheduled_at: 2.hours.ago)

    result = Scheduling::Commands::ConfirmAppointment.call(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-confirm-finished"
    )

    assert_not result.ok?
    assert_equal :already_finished, result.error
    assert_equal appointment, result.appointment
    assert_equal 0, AppointmentEvent.where(idempotency_key: "test-scheduling-confirm-finished").count
  end

  test "returns in_past when the appointment is scheduled in the past" do
    appointment = create_appointment(status: :pending, scheduled_at: 5.minutes.ago)

    result = Scheduling::Commands::ConfirmAppointment.call(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-confirm-past"
    )

    assert_not result.ok?
    assert_equal :in_past, result.error
    assert_equal appointment, result.appointment
    assert_equal 0, AppointmentEvent.where(idempotency_key: "test-scheduling-confirm-past").count
  end

  test "returns appointment_not_found for an appointment outside the given space" do
    appointment = create_appointment(status: :pending, scheduled_at: 2.days.from_now)

    result = Scheduling::Commands::ConfirmAppointment.call(
      space: @other_space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-confirm-not-found"
    )

    assert_not result.ok?
    assert_equal :appointment_not_found, result.error
    assert_nil result.appointment
  end

  test "confirming an appointment does not fail slot validation for its current slot" do
    appointment = create_appointment(status: :pending, scheduled_at: 2.days.from_now)

    result = Scheduling::Commands::ConfirmAppointment.call(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-confirm-slot-check"
    )

    assert_predicate result, :ok?
    assert appointment.reload.confirmed?
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
