# frozen_string_literal: true

class RenameClientToCustomer < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :appointments, :clients
    rename_column :appointments, :client_id, :customer_id

    rename_table :clients, :customers

    add_foreign_key :appointments, :customers, column: :customer_id
  end
end
