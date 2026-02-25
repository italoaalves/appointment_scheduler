# frozen_string_literal: true

class RenameAccessAdminToAccessSpaceDashboard < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE user_permissions SET permission = 'access_space_dashboard' WHERE permission = 'access_admin'"
  end

  def down
    execute "UPDATE user_permissions SET permission = 'access_admin' WHERE permission = 'access_space_dashboard'"
  end
end
