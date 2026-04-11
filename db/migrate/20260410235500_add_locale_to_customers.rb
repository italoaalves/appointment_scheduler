# frozen_string_literal: true

class AddLocaleToCustomers < ActiveRecord::Migration[8.0]
  def up
    add_column :customers, :locale, :string

    default_locale = connection.quote(I18n.default_locale.to_s)

    execute <<~SQL.squish
      UPDATE customers
      SET locale = COALESCE(
        (
          SELECT user_preferences.locale
          FROM spaces
          LEFT JOIN user_preferences
            ON user_preferences.user_id = spaces.owner_id
          WHERE spaces.id = customers.space_id
        ),
        #{default_locale}
      )
      WHERE locale IS NULL
    SQL
  end

  def down
    remove_column :customers, :locale
  end
end
