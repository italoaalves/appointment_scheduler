# frozen_string_literal: true

class AddSoftDeleteToAppointments < ActiveRecord::Migration[8.0]
  def up
    add_column :appointments, :discarded_at, :datetime
    add_index :appointments, :discarded_at, name: "index_appointments_on_discarded_at"

    # Recreate unique active-slot index to exclude soft-deleted records
    remove_index :appointments, name: "index_appointments_unique_active_slot"
    add_index :appointments, [ :space_id, :scheduled_at ],
              name: "index_appointments_unique_active_slot",
              unique: true,
              where: "status IN (0, 1, 3) AND scheduled_at IS NOT NULL AND discarded_at IS NULL"
  end

  def down
    remove_index :appointments, name: "index_appointments_unique_active_slot"
    add_index :appointments, [ :space_id, :scheduled_at ],
              name: "index_appointments_unique_active_slot",
              unique: true,
              where: "status IN (0, 1, 3) AND scheduled_at IS NOT NULL"

    remove_index :appointments, name: "index_appointments_on_discarded_at"
    remove_column :appointments, :discarded_at
  end
end
