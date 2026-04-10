# frozen_string_literal: true

class StoredFile < ApplicationRecord
  PROFILE_PICTURE_SCOPE = "profile_picture"
  SPACE_BANNER_SCOPE = "space_banner"
  SCOPES = [
    PROFILE_PICTURE_SCOPE,
    SPACE_BANNER_SCOPE
  ].freeze

  belongs_to :attachable, polymorphic: true, inverse_of: :stored_files
  belongs_to :space, optional: true

  scope :for_scope, ->(value) { where(scope: value.to_s) }

  before_validation :assign_space_from_attachable

  validates :scope, presence: true, inclusion: { in: SCOPES }, uniqueness: { scope: %i[attachable_type attachable_id] }
  validates :storage_adapter, :storage_path, :original_filename, :content_type, :byte_size, :checksum, presence: true
  validates :byte_size, numericality: { greater_than: 0 }
  validate :space_matches_attachable

  private

  def assign_space_from_attachable
    return if space.present?

    self.space = derived_space
  end

  def space_matches_attachable
    expected_space = derived_space
    return if expected_space.blank? && space.blank?

    if expected_space.present? && space.blank?
      errors.add(:space, :blank)
      return
    end

    return if expected_space.blank? || space == expected_space

    errors.add(:space, :invalid)
  end

  def derived_space
    return attachable if attachable.is_a?(Space)
    return attachable.space if attachable.respond_to?(:space)

    nil
  end
end
