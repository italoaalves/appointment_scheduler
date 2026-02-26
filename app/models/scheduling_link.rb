# frozen_string_literal: true

class SchedulingLink < ApplicationRecord
  include SpaceScoped

  belongs_to :space

  enum :link_type, { permanent: 0, single_use: 1 }

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true, if: :single_use?
  validates :expires_at, absence: true, if: :permanent?

  before_validation :generate_token, on: :create

  scope :usable, -> { where(link_type: :permanent).or(where(link_type: :single_use).where(used_at: nil).where("expires_at > ?", Time.current)) }

  def usable?
    return false if single_use? && used_at.present?
    return false if single_use? && expires_at.present? && expires_at <= Time.current
    true
  end

  def mark_used!
    update!(used_at: Time.current) if single_use?
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(16)
  end
end
