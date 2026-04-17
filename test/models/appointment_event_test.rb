# frozen_string_literal: true

require "test_helper"

class AppointmentEventTest < ActiveSupport::TestCase
  def valid_attrs
    {
      space: spaces(:one),
      appointment: appointments(:one),
      actor: users(:manager),
      actor_label: "user:manager",
      event_type: "appointment.confirmed",
      idempotency_key: SecureRandom.uuid
    }
  end

  test "appointment event can be created" do
    event = AppointmentEvent.create!(valid_attrs)

    assert event.persisted?
  end

  test "event_type is required" do
    event = AppointmentEvent.new(valid_attrs.merge(event_type: nil))

    assert_not event.valid?
    assert event.errors[:event_type].any?
  end

  test "actor_type is required" do
    event = AppointmentEvent.new(valid_attrs.except(:actor).merge(actor_type: nil, actor_id: nil))

    assert_not event.valid?
    assert event.errors[:actor_type].any?
  end

  test "idempotency_key is required" do
    event = AppointmentEvent.new(valid_attrs.merge(idempotency_key: nil))

    assert_not event.valid?
    assert event.errors[:idempotency_key].any?
  end

  test "system events can omit actor_id" do
    event = AppointmentEvent.create!(
      valid_attrs.except(:actor).merge(
        actor_type: "System",
        actor_id: nil,
        actor_label: "system:bot"
      )
    )

    assert_nil event.actor_id
    assert_equal "System", event.actor_type
  end

  test "persisted events cannot be updated" do
    event = appointment_events(:one)

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      event.update!(event_type: "appointment.cancelled")
    end
  end

  test "persisted events cannot be saved after mutation" do
    event = appointment_events(:one)
    event.event_type = "appointment.cancelled"

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      event.save!
    end
  end

  test "idempotency_key is unique" do
    AppointmentEvent.create!(valid_attrs.merge(idempotency_key: "duplicate-key"))

    assert_raises(ActiveRecord::RecordNotUnique) do
      AppointmentEvent.create!(valid_attrs.merge(idempotency_key: "duplicate-key"))
    end
  end

  test "metadata defaults to empty hash" do
    event = AppointmentEvent.create!(valid_attrs)

    assert_equal({}, event.metadata)
  end

  test "composite appointment timeline query uses the lookup index" do
    explain_rows = AppointmentEvent.transaction do
      AppointmentEvent.connection.execute("SET LOCAL enable_seqscan = off")
      AppointmentEvent.connection.select_rows(<<~SQL)
        EXPLAIN SELECT * FROM appointment_events
        WHERE space_id = #{spaces(:one).id}
          AND appointment_id = #{appointments(:one).id}
        ORDER BY created_at ASC
      SQL
    end

    assert_match "idx_appt_events_space_appointment_created_at", explain_rows.join("\n")
  end
end
