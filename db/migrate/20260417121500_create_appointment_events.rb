# frozen_string_literal: true

class CreateAppointmentEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :appointment_events do |t|
      t.references :space,       null: false, foreign_key: true, index: true
      t.references :appointment, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :actor_type, null: false
      t.bigint :actor_id
      t.string :actor_label
      t.string :idempotency_key, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :appointment_events, [ :space_id, :appointment_id, :created_at ],
              name: "idx_appt_events_space_appointment_created_at"
    add_index :appointment_events, :idempotency_key, unique: true
  end
end
