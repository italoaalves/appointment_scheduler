# frozen_string_literal: true

class CreateAvailabilityTables < ActiveRecord::Migration[8.0]
  def change
    create_table :availability_schedules do |t|
      t.references :schedulable, polymorphic: true, null: false, index: true
      t.string :timezone

      t.timestamps
    end

    create_table :availability_windows do |t|
      t.references :availability_schedule, null: false, foreign_key: true
      t.integer :weekday, null: false
      t.time :opens_at, null: false
      t.time :closes_at, null: false

      t.timestamps
    end

    add_index :availability_windows, [ :availability_schedule_id, :weekday ],
              name: "index_availability_windows_on_schedule_weekday"

    create_table :availability_exceptions do |t|
      t.references :availability_schedule, null: false, foreign_key: true
      t.string :name
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.integer :kind, null: false, default: 0
      t.time :opens_at
      t.time :closes_at

      t.timestamps
    end

    add_index :availability_exceptions, [ :availability_schedule_id, :starts_on, :ends_on ],
              name: "index_availability_exceptions_on_schedule_dates"
  end
end
