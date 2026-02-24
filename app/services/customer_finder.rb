# frozen_string_literal: true

class CustomerFinder
  def self.find_or_create(space:, email:, name: nil, phone: nil, address: nil)
    name = name.to_s.strip.presence || "Guest"
    customer = space.customers.find_by("LOWER(email) = ?", email.downcase) if email.present?
    customer ||= space.customers.create!(name: name, phone: phone, email: email, address: address)
    customer
  end
end
