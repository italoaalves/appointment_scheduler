class AddSpaceToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :space, foreign_key: true
  end
end

