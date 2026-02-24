class Appointment < ApplicationRecord
  belongs_to :space
  belongs_to :client, optional: true

  validate :client_belongs_to_space, if: :client_id?

  enum :status, {
    pending: 0,
    confirmed: 1,
    cancelled: 2,
    rescheduled: 3
  }

  private

  def client_belongs_to_space
    return unless space_id.present? && client_id.present?

    unless space.client_ids.include?(client_id)
      errors.add(:client_id, :invalid)
    end
  end
end
