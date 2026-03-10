# frozen_string_literal: true

class AddMissingBillingIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # C-07: credit_purchases.asaas_payment_id
    # A functionally equivalent unique partial index already exists:
    # "index_credit_purchases_on_asaas_payment_id" (unique, where: asaas_payment_id IS NOT NULL)
    # Added in create_credit_purchases migration — no duplicate needed.

    # C-08: Idempotency check in WebhookProcessor#already_processed?
    # billing_events is append-only and grows monotonically; a JSONB expression index
    # prevents full-table scans on every webhook handler invocation.
    add_index :billing_events,
              "(metadata->>'asaas_payment_id')",
              where: "metadata->>'asaas_payment_id' IS NOT NULL",
              algorithm: :concurrently,
              name: "idx_billing_events_metadata_asaas_payment_id"
  end
end
