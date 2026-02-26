# frozen_string_literal: true

class AddPoliciesToSpaces < ActiveRecord::Migration[8.0]
  def change
    add_column :spaces, :cancellation_min_hours_before, :integer
    add_column :spaces, :reschedule_min_hours_before, :integer
    add_column :spaces, :request_max_days_ahead, :integer
    add_column :spaces, :request_min_hours_ahead, :integer
  end
end
