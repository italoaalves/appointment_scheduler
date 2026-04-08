class AddLegalAcceptanceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :terms_of_service_accepted_at, :datetime
    add_column :users, :terms_of_service_version, :string
    add_column :users, :privacy_policy_accepted_at, :datetime
    add_column :users, :privacy_policy_version, :string
  end
end
