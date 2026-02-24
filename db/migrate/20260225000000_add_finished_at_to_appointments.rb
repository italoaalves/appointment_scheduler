# frozen_string_literal: true

class AddFinishedAtToAppointments < ActiveRecord::Migration[8.0]
  def change
    add_column :appointments, :finished_at, :datetime
  end
end
