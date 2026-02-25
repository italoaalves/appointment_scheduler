# frozen_string_literal: true

class MigrateRolesToPermissions < ActiveRecord::Migration[8.0]
  MANAGER_PERMISSIONS = %w[
    access_admin manage_space manage_team manage_customers
    manage_appointments destroy_appointments manage_scheduling_links
    manage_personalized_links own_space
  ].freeze

  SECRETARY_PERMISSIONS = %w[
    access_admin manage_customers manage_appointments manage_scheduling_links
  ].freeze

  def up
    add_column :users, :role_label, :string, default: "", null: false

    User.reset_column_information
    User.unscoped.find_each do |user|
      role_val = user.read_attribute_before_type_cast(:role)
      permissions = role_val == 0 ? MANAGER_PERMISSIONS : (role_val == 1 ? SECRETARY_PERMISSIONS : [])
      role_label = role_val == 0 ? "Manager" : (role_val == 1 ? "Secretary" : "")

      next if permissions.empty?

      now = Time.current
      permissions.each do |perm|
        execute "INSERT INTO user_permissions (user_id, permission, created_at, updated_at) VALUES (#{user.id}, #{connection.quote(perm)}, #{connection.quote(now)}, #{connection.quote(now)})"
      end
      user.update_column(:role_label, role_label)
    end

    remove_column :users, :role
    rename_column :users, :role_label, :role
  end

  def down
    add_column :users, :role_int, :integer, default: 0, null: false

    execute <<-SQL.squish
      UPDATE users
      SET role_int = CASE
        WHEN EXISTS (SELECT 1 FROM user_permissions WHERE user_id = users.id AND permission = 'manage_team')
        THEN 0 ELSE 1
      END
    SQL

    remove_column :users, :role
    rename_column :users, :role_int, :role
  end
end
