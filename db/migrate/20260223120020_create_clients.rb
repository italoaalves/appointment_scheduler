class CreateClients < ActiveRecord::Migration[8.0]
  def change
    create_table :clients do |t|
      t.references :space, null: false, foreign_key: true
      t.string :name, null: false
      t.string :phone
      t.string :address

      t.timestamps
    end
  end
end

