# frozen_string_literal: true

class WhatsappConversation < ApplicationRecord
  belongs_to :space
  belongs_to :customer, optional: true
  has_many :whatsapp_messages, dependent: :destroy

  validates :wa_id,          presence: true, uniqueness: { scope: :space_id }
  validates :customer_phone, presence: true

  scope :unread,  -> { where(unread: true) }
  scope :recent,  -> { order(last_message_at: :desc) }

  def session_active?
    session_expires_at.present? && session_expires_at > Time.current
  end
end
