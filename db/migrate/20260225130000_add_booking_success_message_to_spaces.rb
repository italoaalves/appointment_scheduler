# frozen_string_literal: true

class AddBookingSuccessMessageToSpaces < ActiveRecord::Migration[8.0]
  def change
    add_column :spaces, :booking_success_message, :text
  end
end
