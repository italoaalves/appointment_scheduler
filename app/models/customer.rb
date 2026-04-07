# frozen_string_literal: true

class Customer < ApplicationRecord
  include SpaceScoped

  belongs_to :space
  belongs_to :user, optional: true
  has_many :appointments, dependent: :nullify
  has_many :conversations, dependent: :nullify

  # dependent: :nullify is filtered by Appointment's default_scope (discarded_at: nil),
  # so discarded appointments would still reference the customer and violate the FK.
  # This callback nullifies all appointments regardless of discard state.
  before_destroy :nullify_discarded_appointments

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :email, uniqueness: { scope: :space_id, allow_blank: true }

  private

  def nullify_discarded_appointments
    Appointment.unscoped.where(customer_id: id).update_all(customer_id: nil)
  end
end
