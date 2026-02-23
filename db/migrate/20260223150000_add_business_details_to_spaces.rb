# frozen_string_literal: true

class AddBusinessDetailsToSpaces < ActiveRecord::Migration[8.0]
  def change
    add_column :spaces, :business_type, :string
    add_column :spaces, :address, :text
    add_column :spaces, :phone, :string
    add_column :spaces, :email, :string
    add_column :spaces, :business_hours, :text
    add_column :spaces, :instagram_url, :string
    add_column :spaces, :facebook_url, :string
  end
end
