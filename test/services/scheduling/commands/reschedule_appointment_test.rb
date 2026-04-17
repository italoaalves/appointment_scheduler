# frozen_string_literal: true

require "test_helper"

class Scheduling::Commands::RescheduleAppointmentTest < ActiveSupport::TestCase
  setup do
    @space = spaces(:one)
    @other_space = spaces(:two)
    @customer = customers(:one)
    @actor = users(:manager)
  end

  teardown do
    AppointmentEvent.where("idempotency_key LIKE ?", "test-scheduling-reschedule-%").delete_all
  end

  test "creates a replacement appointment, marks the old one rescheduled, and writes the new appointment id to the event metadata" do
    appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now.change(min: 0))
    new_scheduled_at = appointment.scheduled_at + 2.hours

    result = nil

    assert_difference(-> { @space.appointments.count }, 1) do
      result = Scheduling::Commands::RescheduleAppointment.call(
        space: @space,
        appointment_id: appointment.id,
        actor: @actor,
        idempotency_key: "test-scheduling-reschedule-success",
        metadata: { via: "inbox", reason: "customer_request" },
        new_scheduled_at: new_scheduled_at
      )
    end

    assert_predicate result, :ok?
    assert_equal appointment, result.appointment

    appointment.reload
    event = AppointmentEvent.find(result.event_id)
    replacement = @space.appointments.find(event.metadata.fetch("new_appointment_id"))

    assert appointment.rescheduled?
    assert_equal({ "via" => "inbox", "reason" => "customer_request", "new_appointment_id" => replacement.id }, event.metadata)

    assert_equal @customer, replacement.customer
    assert_equal new_scheduled_at.to_i, replacement.scheduled_at.to_i
    assert_equal appointment.duration_minutes, replacement.duration_minutes
    assert replacement.pending?
    assert replacement.confirmation_not_applicable?
    assert_equal appointment.scheduled_at.to_i, replacement.rescheduled_from.to_i
  end

  test "returns slot_taken and leaves the old appointment untouched when the new slot collides" do
    appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now.change(min: 0))
    create_appointment(
      customer: customers(:two),
      status: :pending,
      scheduled_at: appointment.scheduled_at + 1.hour,
      duration_minutes: appointment.duration_minutes
    )

    result = Scheduling::Commands::RescheduleAppointment.call(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-reschedule-slot-taken",
      new_scheduled_at: appointment.scheduled_at + 1.hour
    )

    assert_not result.ok?
    assert_equal :slot_taken, result.error
    assert_equal appointment, result.appointment

    appointment.reload
    assert appointment.confirmed?
    assert_equal 0, AppointmentEvent.where(idempotency_key: "test-scheduling-reschedule-slot-taken").count
    assert_equal 0, @space.appointments.where(status: :rescheduled).count
  end

  test "replays the original successful result for the same idempotency key without creating another replacement appointment" do
    appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now.change(min: 0))
    idempotency_key = "test-scheduling-reschedule-replay"
    first_time = appointment.scheduled_at + 2.hours

    first = nil

    assert_difference(-> { @space.appointments.count }, 1) do
      first = Scheduling::Commands::RescheduleAppointment.call(
        space: @space,
        appointment_id: appointment.id,
        actor: @actor,
        idempotency_key: idempotency_key,
        metadata: { via: "button" },
        new_scheduled_at: first_time
      )
    end

    second = nil

    assert_no_difference(-> { @space.appointments.count }) do
      second = Scheduling::Commands::RescheduleAppointment.call(
        space: @space,
        appointment_id: appointment.id,
        actor: @actor,
        idempotency_key: idempotency_key,
        metadata: { via: "keyword" },
        new_scheduled_at: first_time + 3.hours
      )
    end

    assert_predicate first, :ok?
    assert_predicate second, :ok?
    assert_equal first.event_id, second.event_id
    assert_equal 1, AppointmentEvent.where(idempotency_key: idempotency_key).count
  end

  test "returns invalid_time when the new slot is in the past" do
    appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now)

    result = Scheduling::Commands::RescheduleAppointment.call(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-reschedule-invalid-time",
      new_scheduled_at: 5.minutes.ago
    )

    assert_not result.ok?
    assert_equal :invalid_time, result.error
    assert_equal appointment, result.appointment
    assert_equal 0, AppointmentEvent.where(idempotency_key: "test-scheduling-reschedule-invalid-time").count
  end

  test "returns appointment_not_found for an appointment outside the given space" do
    appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now)

    result = Scheduling::Commands::RescheduleAppointment.call(
      space: @other_space,
      appointment_id: appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-reschedule-not-found",
      new_scheduled_at: 3.days.from_now
    )

    assert_not result.ok?
    assert_equal :appointment_not_found, result.error
    assert_nil result.appointment
  end

  private

  def create_appointment(customer: @customer, status:, scheduled_at:, duration_minutes: 30)
    @space.appointments.create!(
      customer: customer,
      scheduled_at: scheduled_at,
      status: status,
      duration_minutes: duration_minutes,
      confirmation_state: :awaiting_customer
    )
  end
end
