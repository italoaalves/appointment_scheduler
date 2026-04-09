# frozen_string_literal: true

class AddMfaFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :totp_secret, :string
    add_column :users, :totp_enabled_at, :datetime
    add_column :users, :totp_last_verified_at, :datetime
    add_column :users, :totp_consumed_timestep, :integer
    add_column :users, :mfa_enabled_at, :datetime
    add_column :users, :last_mfa_at, :datetime
  end
end
