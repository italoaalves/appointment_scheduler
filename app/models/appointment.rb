class Appointment < ApplicationRecord
  belongs_to :space
  belongs_to :client, optional: true

  validate :client_belongs_to_space, if: :client_id?

  enum :status, {
    requested: 0,
    confirmed: 1,
    denied: 2,
    cancelled: 3,
    rescheduled: 4
  }

  private

  def client_belongs_to_space
    return unless space_id.present? && client_id.present?

    unless space.client_ids.include?(client_id)
      errors.add(:client_id, :invalid)
    end
  end
end
