# frozen_string_literal: true

class CreateBackupSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :backup_settings do |t|
      t.boolean :enabled, null: false, default: true
      t.string :last_status
      t.datetime :last_run_started_at
      t.datetime :last_run_finished_at
      t.datetime :last_success_at
      t.datetime :last_failure_at
      t.string :last_remote_key
      t.text :last_error

      t.timestamps
    end
  end
end
