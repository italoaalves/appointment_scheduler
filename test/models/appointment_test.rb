# frozen_string_literal: true

require "test_helper"

class AppointmentTest < ActiveSupport::TestCase
  setup do
    @space = spaces(:one)
    @customer = customers(:one)
  end

  test "valid appointment" do
    appointment = @space.appointments.build(
      customer: @customer,
      scheduled_at: 3.days.from_now,
      status: :pending,
      duration_minutes: 30
    )
    assert appointment.valid?
  end

  test "sets duration from space on create" do
    appointment = @space.appointments.build(
      customer: @customer,
      scheduled_at: 3.days.from_now,
      status: :pending
    )
    appointment.valid?
    assert_equal @space.slot_duration_minutes, appointment.duration_minutes
  end

  test "does not overwrite explicit duration" do
    appointment = @space.appointments.build(
      customer: @customer,
      scheduled_at: 3.days.from_now,
      status: :pending,
      duration_minutes: 45
    )
    appointment.valid?
    assert_equal 45, appointment.duration_minutes
  end

  test "customer must belong to same space" do
    other_customer = customers(:other_space_customer)
    appointment = @space.appointments.build(
      customer: other_customer,
      scheduled_at: 3.days.from_now,
      status: :confirmed,
      duration_minutes: 30
    )
    assert_not appointment.valid?
    assert appointment.errors.added?(:customer_id, :invalid)
  end

  test "detects double booking for confirmed appointments" do
    existing = @space.appointments.create!(
      customer: @customer,
      scheduled_at: 3.days.from_now.change(hour: 10),
      status: :confirmed,
      duration_minutes: 30
    )

    overlapping = @space.appointments.build(
      customer: customers(:two),
      scheduled_at: existing.scheduled_at + 15.minutes,
      status: :confirmed,
      duration_minutes: 30
    )
    assert_not overlapping.valid?
    assert overlapping.errors.added?(:base, :slot_already_booked)
  end

  test "allows non-overlapping appointments" do
    existing = @space.appointments.create!(
      customer: @customer,
      scheduled_at: 3.days.from_now.change(hour: 10),
      status: :confirmed,
      duration_minutes: 30
    )

    non_overlapping = @space.appointments.build(
      customer: customers(:two),
      scheduled_at: existing.scheduled_at + 30.minutes,
      status: :confirmed,
      duration_minutes: 30
    )
    assert non_overlapping.valid?
  end

  test "pending appointments are subject to double booking check" do
    existing = @space.appointments.create!(
      customer: @customer,
      scheduled_at: 3.days.from_now.change(hour: 10),
      status: :confirmed,
      duration_minutes: 30
    )

    overlapping_pending = @space.appointments.build(
      customer: customers(:two),
      scheduled_at: existing.scheduled_at + 15.minutes,
      status: :pending,
      duration_minutes: 30
    )
    assert_not overlapping_pending.valid?
    assert overlapping_pending.errors[:base].any?
  end

  test "scheduled_in_past? returns true for past appointments" do
    appointment = Appointment.new(scheduled_at: 1.hour.ago)
    assert appointment.scheduled_in_past?
  end

  test "scheduled_in_past? returns false for future appointments" do
    appointment = Appointment.new(scheduled_at: 1.hour.from_now)
    assert_not appointment.scheduled_in_past?
  end

  test "effective_duration_minutes falls back to space setting" do
    appointment = @space.appointments.build(duration_minutes: nil)
    assert_equal @space.slot_duration_minutes, appointment.effective_duration_minutes
  end
end
