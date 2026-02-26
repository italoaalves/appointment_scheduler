# frozen_string_literal: true

class PersonalizedSchedulingLink < ApplicationRecord
  include SpaceScoped

  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  belongs_to :space

  validates :slug, presence: true, uniqueness: true, format: { with: SLUG_FORMAT }
  validate :slug_change_allowed, on: [ :create, :update ]

  before_validation :normalize_slug, if: :slug_changed?
  after_create :record_slug_change
  after_update :record_slug_change, if: :saved_change_to_slug?

  private

  def normalize_slug
    self.slug = slug.to_s.downcase.strip
  end

  def slug_change_allowed
    return if slug.blank?
    return if persisted? && !slug_changed?

    count = space.personalized_slug_changes_count
    last_at = space.personalized_slug_last_changed_at

    if count >= 3
      errors.add(:slug, :change_limit_reached)
      return
    end

    if last_at.present? && last_at > 14.days.ago
      errors.add(:slug, :change_too_soon)
    end
  end

  def record_slug_change
    space.increment!(:personalized_slug_changes_count)
    space.update_column(:personalized_slug_last_changed_at, Time.current)
  end
end
