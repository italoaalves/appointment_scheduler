# frozen_string_literal: true

class Conversation < ApplicationRecord
  belongs_to :space
  belongs_to :customer, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true
  has_many :conversation_messages, dependent: :destroy

  enum :channel, { whatsapp: 0, email: 1, sms: 2, instagram: 3, messenger: 4 }
  enum :status, { automated: 0, needs_reply: 1, open: 2, pending: 3, resolved: 4, closed: 5 }
  enum :priority, { low: 0, normal: 1, high: 2, urgent: 3 }

  validates :channel, :status, :priority, :external_id, :contact_identifier, presence: true
  validates :external_id, uniqueness: { scope: [ :space_id, :channel ] }

  scope :active, -> { where(status: [ :needs_reply, :open, :pending ]) }
  scope :needing_attention, -> { where(status: [ :needs_reply, :open, :pending ]) }
  scope :for_default_inbox, -> { needing_attention }

  def session_active?
    session_expires_at.present? && session_expires_at > Time.current
  end
end
