# frozen_string_literal: true

class CreateAccountDeletionRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :account_deletion_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.datetime :requested_at, null: false
      t.datetime :scheduled_for, null: false
      t.datetime :canceled_at

      t.timestamps
    end

    add_index :account_deletion_requests, :user_id, unique: true, where: "status = 0", name: "index_account_deletion_requests_on_pending_user_id"
  end
end
