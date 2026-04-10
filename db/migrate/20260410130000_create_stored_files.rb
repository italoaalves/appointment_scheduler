class CreateStoredFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :stored_files do |t|
      t.references :space, foreign_key: true
      t.references :attachable, polymorphic: true, null: false
      t.string :scope, null: false
      t.string :storage_adapter, null: false
      t.string :storage_path, null: false
      t.string :original_filename, null: false
      t.string :content_type, null: false
      t.bigint :byte_size, null: false
      t.string :checksum, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :stored_files, [ :attachable_type, :attachable_id, :scope ], unique: true
    add_index :stored_files, :scope
    add_index :stored_files, [ :space_id, :scope ]
  end
end
