# frozen_string_literal: true

class Customer < ApplicationRecord
  include SpaceScoped

  encrypts :phone, deterministic: true
  encrypts :address

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

  def whatsapp_opted_in?
    return false if whatsapp_opted_in_at.blank?

    whatsapp_opted_out_at.blank? || whatsapp_opted_in_at > whatsapp_opted_out_at
  end

  def grant_whatsapp_consent(source:, at: Time.current)
    self.whatsapp_opted_in_at = at
    self.whatsapp_opt_in_source = source.to_s
  end

  def revoke_whatsapp_consent(source:, at: Time.current)
    self.whatsapp_opted_out_at = at
    self.whatsapp_opt_out_source = source.to_s
  end

  def apply_whatsapp_consent(checked:, source:, at: Time.current, revoke_on_uncheck: false)
    checked = ActiveModel::Type::Boolean.new.cast(checked)

    if checked
      grant_whatsapp_consent(source: source, at: at)
    elsif revoke_on_uncheck && whatsapp_opted_in?
      revoke_whatsapp_consent(source: source, at: at)
    end
  end

  private

  def nullify_discarded_appointments
    Appointment.unscoped.where(customer_id: id).update_all(customer_id: nil)
  end
end
