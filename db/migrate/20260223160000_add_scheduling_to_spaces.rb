# frozen_string_literal: true

class AddSchedulingToSpaces < ActiveRecord::Migration[8.0]
  def change
    add_column :spaces, :slot_duration_minutes, :integer, default: 30, null: false
    add_column :spaces, :business_hours_schedule, :jsonb, default: {}
  end
end
