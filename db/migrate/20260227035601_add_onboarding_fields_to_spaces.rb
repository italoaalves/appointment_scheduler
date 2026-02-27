class AddOnboardingFieldsToSpaces < ActiveRecord::Migration[8.0]
  def change
    add_column :spaces, :onboarding_step, :integer, default: 0, null: false
    add_column :spaces, :completed_onboarding_at, :datetime
    add_column :spaces, :onboarding_nudge_sent_at, :datetime
  end
end
