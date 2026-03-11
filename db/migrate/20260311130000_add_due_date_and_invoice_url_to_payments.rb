# frozen_string_literal: true

class AddDueDateAndInvoiceUrlToPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :due_date,    :date
    add_column :payments, :invoice_url, :string

    add_index :payments, [ :status, :payment_method, :due_date ],
              name: "index_payments_on_status_method_due_date"
  end
end
