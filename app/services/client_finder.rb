# frozen_string_literal: true

class ClientFinder
  def self.find_or_create(space:, email:, name: nil, phone: nil, address: nil)
    name = name.to_s.strip.presence || "Guest"
    client = space.clients.find_by("LOWER(email) = ?", email.downcase) if email.present?
    client ||= space.clients.create!(name: name, phone: phone, email: email, address: address)
    client
  end
end
