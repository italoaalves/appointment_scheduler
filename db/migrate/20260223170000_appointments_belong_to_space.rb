# frozen_string_literal: true

class AppointmentsBelongToSpace < ActiveRecord::Migration[8.0]
  def up
    add_column :appointments, :space_id, :bigint
    add_index :appointments, :space_id

    # Migrate existing data: set space_id from user's space (skip users without space, e.g. admin)
    execute <<-SQL.squish
      UPDATE appointments
      SET space_id = users.space_id
      FROM users
      WHERE appointments.user_id = users.id
        AND users.space_id IS NOT NULL
    SQL

    # Delete any appointments whose user has no space (orphaned)
    execute <<-SQL.squish
      DELETE FROM appointments
      WHERE space_id IS NULL
    SQL

    change_column_null :appointments, :space_id, false
    add_foreign_key :appointments, :spaces

    remove_foreign_key :appointments, :users
    remove_column :appointments, :user_id
  end

  def down
    add_column :appointments, :user_id, :bigint
    add_index :appointments, :user_id
    add_foreign_key :appointments, :users

    # Reverse migration: assign to first manager of space (best effort)
    execute <<-SQL.squish
      UPDATE appointments
      SET user_id = (
        SELECT id FROM users
        WHERE users.space_id = appointments.space_id
        ORDER BY role ASC
        LIMIT 1
      )
      FROM spaces
      WHERE appointments.space_id = spaces.id
    SQL

    change_column_null :appointments, :user_id, false

    remove_foreign_key :appointments, :spaces
    remove_column :appointments, :space_id
  end
end
