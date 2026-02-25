# frozen_string_literal: true

class DropAvailabilityExceptions < ActiveRecord::Migration[8.0]
  def up
    drop_table :availability_exceptions, if_exists: true
  end

  def down
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
