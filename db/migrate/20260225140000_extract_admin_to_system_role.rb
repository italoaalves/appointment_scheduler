# frozen_string_literal: true

class ExtractAdminToSystemRole < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :system_role, :integer, null: true, default: nil

    # Only users with role=0 (admin) get super_admin. Everyone else stays nil.
    # Then renumber roles: admin(0)->secretary(1), manager(1)->manager(0), secretary(2)->secretary(1)
    execute <<-SQL.squish
      UPDATE users SET
        system_role = CASE WHEN role = 0 THEN 0 ELSE NULL END,
        role = CASE role
          WHEN 0 THEN 1
          WHEN 1 THEN 0
          WHEN 2 THEN 1
        END
    SQL

    change_column_default :users, :role, from: 1, to: 0
  end

  def down
    change_column_default :users, :role, from: 0, to: 1

    # Revert: super_admin -> role 0 (admin); manager (0) -> 1; secretary (1) -> 2
    execute "UPDATE users SET role = 0 WHERE system_role = 0"
    execute "UPDATE users SET role = 1 WHERE system_role IS NULL AND role = 0"
    execute "UPDATE users SET role = 2 WHERE system_role IS NULL AND role = 1"

    remove_column :users, :system_role
  end
end
