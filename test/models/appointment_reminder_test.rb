# frozen_string_literal: true

require "test_helper"

class AppointmentReminderTest < ActiveSupport::TestCase
  setup do
    @space = spaces(:one)
    @other_space = spaces(:two)
    @appointment = appointments(:one)
    @other_appointment = @other_space.appointments.create!(
      customer: customers(:other_space_customer),
      scheduled_at: 2.days.from_now.change(hour: 16),
      status: :confirmed,
      duration_minutes: 30
    )
  end

  test "live reminders are unique per appointment and kind" do
    reminder = AppointmentReminder.create!(
      space: @space,
      appointment: @appointment,
      kind: Scheduling::Reminders::Kinds::CONFIRMATION_24H,
      fire_at: 24.hours.from_now,
      status: :scheduled
    )

    AppointmentReminder.transaction(requires_new: true) do
      assert_raises(ActiveRecord::RecordNotUnique) do
        AppointmentReminder.insert_all!([ {
          space_id: @space.id,
          appointment_id: @appointment.id,
          kind: Scheduling::Reminders::Kinds::CONFIRMATION_24H,
          channel: "whatsapp",
          status: AppointmentReminder.statuses[:queued],
          fire_at: 2.hours.from_now,
          created_at: Time.current,
          updated_at: Time.current
        } ])
      end

      raise ActiveRecord::Rollback
    end

    duplicate = AppointmentReminder.new(
      space: @space,
      appointment: @appointment,
      kind: reminder.kind,
      fire_at: 2.hours.from_now,
      status: :queued
    )

    assert_not duplicate.valid?
    assert duplicate.errors[:kind].any?
  end

  test "superseded reminders do not block a new live reminder for the same kind" do
    AppointmentReminder.create!(
      space: @space,
      appointment: @appointment,
      kind: Scheduling::Reminders::Kinds::CONFIRMATION_2H,
      fire_at: 2.hours.from_now,
      status: :superseded
    )

    reminder = AppointmentReminder.create!(
      space: @space,
      appointment: @appointment,
      kind: Scheduling::Reminders::Kinds::CONFIRMATION_2H,
      fire_at: 90.minutes.from_now,
      status: :scheduled
    )

    assert_predicate reminder, :persisted?
  end

  test "due returns only scheduled reminders at or before the cutoff" do
    due_reminder = AppointmentReminder.create!(
      space: @space,
      appointment: @appointment,
      kind: Scheduling::Reminders::Kinds::CONFIRMATION_24H,
      fire_at: 5.minutes.ago,
      status: :scheduled
    )
    AppointmentReminder.create!(
      space: @space,
      appointment: @appointment,
      kind: Scheduling::Reminders::Kinds::CONFIRMATION_2H,
      fire_at: 10.minutes.from_now,
      status: :scheduled
    )
    AppointmentReminder.create!(
      space: @space,
      appointment: @appointment,
      kind: "post_visit_feedback",
      fire_at: 10.minutes.ago,
      status: :queued
    )

    assert_equal [ due_reminder.id ], AppointmentReminder.due.pluck(:id)
  end

  test "dispatcher due query uses the scan index" do
    AppointmentReminder.create!(
      space: @space,
      appointment: @appointment,
      kind: Scheduling::Reminders::Kinds::CONFIRMATION_24H,
      fire_at: 5.minutes.ago,
      status: :scheduled
    )

    explain_rows = AppointmentReminder.transaction do
      AppointmentReminder.connection.execute("SET LOCAL enable_seqscan = off")
      AppointmentReminder.connection.select_rows(<<~SQL)
        EXPLAIN SELECT * FROM appointment_reminders
        WHERE status = #{AppointmentReminder.statuses[:scheduled]}
          AND fire_at <= '#{Time.current.utc.to_fs(:db)}'
      SQL
    end

    assert_match "idx_reminders_dispatcher_scan", explain_rows.join("\n")
  end

  test "space scoped hides reminders from other tenants" do
    own_reminder = AppointmentReminder.create!(
      space: @space,
      appointment: @appointment,
      kind: Scheduling::Reminders::Kinds::CONFIRMATION_24H,
      fire_at: 1.hour.from_now
    )
    other_reminder = AppointmentReminder.create!(
      space: @other_space,
      appointment: @other_appointment,
      kind: Scheduling::Reminders::Kinds::CONFIRMATION_2H,
      fire_at: 2.hours.from_now
    )

    Current.set(space: @space) do
      assert_equal [ own_reminder.id ], AppointmentReminder.pluck(:id)
      assert_not_includes AppointmentReminder.pluck(:id), other_reminder.id
    end
  end

  test "kinds exposes the supported confirmation reminder constants" do
    assert_equal "confirmation_24h", Scheduling::Reminders::Kinds::CONFIRMATION_24H
    assert_equal "confirmation_2h", Scheduling::Reminders::Kinds::CONFIRMATION_2H
  end
end
