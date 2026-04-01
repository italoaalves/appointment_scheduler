# frozen_string_literal: true

class WhatsappPhoneNumber < ApplicationRecord
  belongs_to :space, optional: true

  enum :status, { pending_verification: 0, active: 1, disconnected: 2 }

  validates :phone_number_id, presence: true, uniqueness: true
  validates :display_number, presence: true
  validates :waba_id, presence: true
  validates :space_id, uniqueness: true, allow_nil: true

  scope :system_bot, -> { where(space_id: nil) }

  def system_bot?
    space_id.nil?
  end
end
