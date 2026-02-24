class CreateSpaces < ActiveRecord::Migration[8.0]
  def change
    create_table :spaces do |t|
      t.string :name, null: false
      t.string :timezone

      t.timestamps
    end
  end
end
