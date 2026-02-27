# frozen_string_literal: true

module Billing
  class Plan < ApplicationRecord
    self.table_name = "billing_plans"

    KNOWN_FEATURES = %w[
      personalized_booking_page
      custom_appointment_policies
      whatsapp_included_quota
      priority_support
    ].freeze

    validates :slug,        presence: true, uniqueness: true,
                            format: { with: /\A[a-z0-9_]+\z/ }
    validates :name,        presence: true
    validates :price_cents, presence: true,
                            numericality: { greater_than_or_equal_to: 0 }
    validates :position,    presence: true

    scope :active,  -> { where(active: true) }
    scope :visible, -> { active.where(public: true).order(:position) }

    def free?
      price_cents.zero?
    end

    def feature?(flag)
      features.include?(flag.to_s)
    end

    # Returns the raw column value. nil means unlimited.
    def limit(attribute)
      public_send(attribute)
    end

    # nil = unlimited → never reached.
    def limit_reached?(attribute, current_count)
      max = read_attribute(attribute)
      return false if max.nil?
      current_count >= max
    end

    def whatsapp_unlimited?
      read_attribute(:whatsapp_monthly_quota).nil?
    end

    def requires_payment_method?(method)
      return true if allowed_payment_methods.blank?
      allowed_payment_methods.include?(method.to_s)
    end

    def self.trial_plan
      find_by!(trial_default: true)
    end

    def self.find_by_slug!(slug)
      find_by!(slug: slug)
    end
  end
end
