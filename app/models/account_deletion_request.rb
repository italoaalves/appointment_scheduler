# frozen_string_literal: true

class AccountDeletionRequest < ApplicationRecord
  belongs_to :user

  enum :status, { pending: 0, canceled: 1, completed: 2 }, default: :pending

  validates :requested_at, :scheduled_for, :status, presence: true

  scope :active, -> { pending.order(requested_at: :desc) }
end
