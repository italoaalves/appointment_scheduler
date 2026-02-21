class CreateAppointments < ActiveRecord::Migration[8.0]
  def change
    create_table :appointments do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :requested_at
      t.datetime :scheduled_at
      t.datetime :rescheduled_from
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
