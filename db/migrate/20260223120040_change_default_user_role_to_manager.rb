# frozen_string_literal: true

class ChangeDefaultUserRoleToManager < ActiveRecord::Migration[8.0]
  def up
    change_column_default :users, :role, from: 0, to: 1
  end

  def down
    change_column_default :users, :role, from: 1, to: 0
  end
end
