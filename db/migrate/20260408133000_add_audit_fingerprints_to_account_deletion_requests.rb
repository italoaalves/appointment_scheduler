# frozen_string_literal: true

class AddAuditFingerprintsToAccountDeletionRequests < ActiveRecord::Migration[8.1]
  def change
    change_table :account_deletion_requests, bulk: true do |t|
      t.datetime :completed_at
      t.string :email_fingerprint
      t.string :name_fingerprint
      t.string :phone_fingerprint
      t.string :cpf_cnpj_fingerprint
    end

    add_index :account_deletion_requests, :completed_at
    add_index :account_deletion_requests, :email_fingerprint
    add_index :account_deletion_requests, :name_fingerprint
    add_index :account_deletion_requests, :phone_fingerprint
    add_index :account_deletion_requests, :cpf_cnpj_fingerprint
    add_index :account_deletion_requests, [ :status, :scheduled_for ]
  end
end
