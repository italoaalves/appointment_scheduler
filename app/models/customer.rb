# frozen_string_literal: true

class Customer < ApplicationRecord
  belongs_to :space
  belongs_to :user, optional: true
  has_many :appointments, dependent: :nullify

  validates :name, presence: true
end
