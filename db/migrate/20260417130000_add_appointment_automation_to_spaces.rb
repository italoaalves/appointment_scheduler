# frozen_string_literal: true

class AddAppointmentAutomationToSpaces < ActiveRecord::Migration[8.0]
  def change
    add_column :spaces, :appointment_automation_enabled, :boolean, null: false, default: false
    add_column :spaces, :confirmation_lead_hours, :integer, array: true, null: false, default: [ 24, 2 ]
    add_column :spaces, :confirmation_quiet_hours_start, :time
    add_column :spaces, :confirmation_quiet_hours_end, :time

    add_index :spaces, :appointment_automation_enabled, where: "appointment_automation_enabled = true"
  end
end
