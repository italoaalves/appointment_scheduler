# frozen_string_literal: true

class CreateAppointmentReminders < ActiveRecord::Migration[8.0]
  def change
    create_table :appointment_reminders do |t|
      t.references :space, null: false, foreign_key: true, index: true
      t.references :appointment, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :channel, null: false, default: "whatsapp"
      t.integer :status, null: false, default: 0
      t.datetime :fire_at, null: false
      t.datetime :sent_at
      t.datetime :delivered_at
      t.string :template_name
      t.string :template_version
      t.string :wamid
      t.string :action_token_digest
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :appointment_reminders, [ :appointment_id, :kind ],
              unique: true,
              where: "status IN (0,1,2,3)",
              name: "idx_reminders_one_live_per_kind"

    add_index :appointment_reminders, [ :status, :fire_at ],
              name: "idx_reminders_dispatcher_scan"

    add_index :appointment_reminders, :wamid,
              unique: true,
              where: "wamid IS NOT NULL"
  end
end
