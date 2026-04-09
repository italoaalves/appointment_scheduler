# frozen_string_literal: true

class UserRecoveryCode < ApplicationRecord
  belongs_to :user

  scope :active, -> { where(used_at: nil) }

  validates :code_digest, presence: true
end
