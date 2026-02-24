# frozen_string_literal: true

class ConvertDeniedAppointmentsToCancelled < ActiveRecord::Migration[8.0]
  def up
    # Old: pending=0, confirmed=1, denied=2, cancelled=3, rescheduled=4
    # New: pending=0, confirmed=1, cancelled=2, rescheduled=3
    # Convert: denied(2) and cancelled(3) -> 2; rescheduled(4) -> 3
    execute "UPDATE appointments SET status = 3 WHERE status = 4" # rescheduled first
    execute "UPDATE appointments SET status = 2 WHERE status IN (2, 3)" # denied + cancelled -> cancelled
  end

  def down
    # Cannot reliably revert - leave as cancelled
  end
end
