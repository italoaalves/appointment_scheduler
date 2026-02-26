# frozen_string_literal: true

class AddUniqueIndexForActiveAppointmentSlots < ActiveRecord::Migration[8.0]
  def change
    add_index :appointments, [ :space_id, :scheduled_at ],
              name: "index_appointments_unique_active_slot",
              unique: true,
              where: "status IN (0, 1, 3) AND scheduled_at IS NOT NULL"
  end
end
