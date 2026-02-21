class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.text :content
      t.integer :channel, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.references :messageable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
