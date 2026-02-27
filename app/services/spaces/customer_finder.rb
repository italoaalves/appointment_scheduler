# frozen_string_literal: true

module Spaces
  class CustomerFinder
    def self.find_or_create(space:, email:, name: nil, phone: nil, address: nil)
      raise ArgumentError, "email or phone is required" if email.blank? && phone.blank?

      name = name.to_s.strip.presence || "Guest"
      customer = space.customers.find_by("LOWER(email) = LOWER(?)", email) if email.present?
      customer ||= space.customers.find_by(phone: phone) if phone.present? && customer.nil?
      customer ||= space.customers.create!(name: name, phone: phone, email: email, address: address)
      customer
    end

    def self.find_existing(space:, email: nil, phone: nil)
      customer = space.customers.find_by("LOWER(email) = LOWER(?)", email) if email.present?
      customer ||= space.customers.find_by(phone: phone) if phone.present? && customer.nil?
      customer
    end
  end
end
