# frozen_string_literal: true

class Customer < ApplicationRecord
  include SpaceScoped

  belongs_to :space
  belongs_to :user, optional: true
  has_many :appointments, dependent: :nullify

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :email, uniqueness: { scope: :space_id, allow_blank: true }
end
