# frozen_string_literal: true

class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :appointments, [ :space_id, :status, :scheduled_at ],
              name: "index_appointments_on_space_status_scheduled_at"

    add_index :appointments, [ :client_id, :scheduled_at ],
              name: "index_appointments_on_client_scheduled_at"
  end
end
