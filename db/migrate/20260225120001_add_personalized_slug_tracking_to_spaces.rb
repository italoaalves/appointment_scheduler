# frozen_string_literal: true

class AddPersonalizedSlugTrackingToSpaces < ActiveRecord::Migration[8.0]
  def change
    add_column :spaces, :personalized_slug_changes_count, :integer, default: 0, null: false
    add_column :spaces, :personalized_slug_last_changed_at, :datetime
  end
end
