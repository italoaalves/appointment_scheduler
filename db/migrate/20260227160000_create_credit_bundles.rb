class CreateCreditBundles < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_bundles do |t|
      t.string  :name,        null: false
      t.integer :amount,      null: false
      t.integer :price_cents, null: false
      t.integer :position,    null: false, default: 0
      t.boolean :active,      null: false, default: true
      t.timestamps
    end

    add_index :credit_bundles, :position
  end
end
