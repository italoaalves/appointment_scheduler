# frozen_string_literal: true

class UserPasskey < ApplicationRecord
  belongs_to :user

  validates :external_id, :public_key, :label, presence: true
  validates :external_id, uniqueness: true
  validates :sign_count, numericality: { greater_than_or_equal_to: 0 }
end
