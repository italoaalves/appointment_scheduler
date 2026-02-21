class CreateAppointments < ActiveRecord::Migration[8.0]
  def change
    create_table :appointments do |t|
      t.references :client, null: false, foreign_key: { to_table: :users }
      t.references :managed_by, foreign_key: { to_table: :users }
      t.datetime :requested_at
      t.datetime :scheduled_at
      t.datetime :rescheduled_from
      t.integer :status, default: 0, null: false
      t.text :client_notes
      t.text :admin_notes

      t.timestamps
    end
  end
end
