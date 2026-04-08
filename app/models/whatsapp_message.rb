# frozen_string_literal: true

class WhatsappMessage < ApplicationRecord
  encrypts :body

  belongs_to :whatsapp_conversation
  belongs_to :sent_by, class_name: "User", optional: true

  enum :direction, { inbound: 0, outbound: 1 }
  enum :status,    { pending: 0, sent: 1, delivered: 2, read: 3, failed: 4 }

  validates :direction, presence: true

  scope :chronological, -> { order(created_at: :asc) }

  def status_progression_valid?(new_status)
    return true if new_status.to_s == "failed"

    self.class.statuses[new_status.to_s] > self.class.statuses[status]
  end
end
