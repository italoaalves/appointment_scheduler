# frozen_string_literal: true

class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :actor_user, foreign_key: { to_table: :users }
      t.references :space, foreign_key: true
      t.string :event_type, null: false
      t.string :auditable_type
      t.bigint :auditable_id
      t.string :subject_type
      t.bigint :subject_id
      t.string :subject_email_fingerprint
      t.string :subject_phone_fingerprint
      t.string :subject_cpf_cnpj_fingerprint
      t.string :subject_name_fingerprint
      t.string :request_id
      t.string :ip_address
      t.boolean :impersonated, null: false, default: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :audit_logs, :event_type
    add_index :audit_logs, :created_at
    add_index :audit_logs, [ :space_id, :created_at ]
    add_index :audit_logs, [ :actor_user_id, :created_at ]
    add_index :audit_logs, [ :auditable_type, :auditable_id ]
    add_index :audit_logs, [ :subject_type, :subject_id ]
    add_index :audit_logs, :subject_email_fingerprint
    add_index :audit_logs, :subject_phone_fingerprint
    add_index :audit_logs, :subject_cpf_cnpj_fingerprint
    add_index :audit_logs, :subject_name_fingerprint
  end
end
