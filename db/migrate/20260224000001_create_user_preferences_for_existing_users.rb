# frozen_string_literal: true

class CreateUserPreferencesForExistingUsers < ActiveRecord::Migration[8.0]
  def up
    return unless table_exists?(:users) && table_exists?(:user_preferences)

    execute <<-SQL.squish
      INSERT INTO user_preferences (user_id, locale, created_at, updated_at)
      SELECT id, 'pt-BR', NOW(), NOW()
      FROM users
      WHERE NOT EXISTS (
        SELECT 1 FROM user_preferences WHERE user_preferences.user_id = users.id
      )
    SQL
  end

  def down
    # No-op: user_preferences are populated; down is handled by create_user_preferences rollback
  end
end
