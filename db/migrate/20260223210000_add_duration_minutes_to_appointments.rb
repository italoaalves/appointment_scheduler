# frozen_string_literal: true

class AddDurationMinutesToAppointments < ActiveRecord::Migration[8.0]
  def change
    add_column :appointments, :duration_minutes, :integer

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE appointments
          SET duration_minutes = spaces.slot_duration_minutes
          FROM spaces
          WHERE appointments.space_id = spaces.id
        SQL
      end
    end

    change_column_null :appointments, :duration_minutes, true
  end
end
