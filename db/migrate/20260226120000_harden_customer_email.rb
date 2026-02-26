# frozen_string_literal: true

class HardenCustomerEmail < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE INDEX index_customers_on_space_id_lower_email
      ON customers (space_id, LOWER(email))
      WHERE email IS NOT NULL
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS index_customers_on_space_id_lower_email"
  end
end
