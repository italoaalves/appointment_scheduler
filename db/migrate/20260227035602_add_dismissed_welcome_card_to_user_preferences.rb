class AddDismissedWelcomeCardToUserPreferences < ActiveRecord::Migration[8.0]
  def change
    add_column :user_preferences, :dismissed_welcome_card, :boolean, default: false, null: false
  end
end
