class Client < ApplicationRecord
  belongs_to :space
  has_many :appointments, dependent: :nullify

  validates :name, presence: true
end

