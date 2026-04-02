# frozen_string_literal: true

class ConversationMessage < ApplicationRecord
  belongs_to :conversation, touch: true
  belongs_to :sent_by, class_name: "User", optional: true

  enum :direction, { inbound: 0, outbound: 1 }
  enum :status, { pending: 0, sent: 1, delivered: 2, read: 3, failed: 4 }

  validates :direction, presence: true

  scope :chronological, -> { order(created_at: :asc) }
end
