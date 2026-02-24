# frozen_string_literal: true

class UserPreference < ApplicationRecord
  belongs_to :user

  validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }

  before_validation :set_default_locale, on: :create

  private

  def set_default_locale
    self.locale ||= I18n.default_locale.to_s
  end
end
