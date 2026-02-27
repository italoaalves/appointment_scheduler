# frozen_string_literal: true

module Billing
  CreditBundle = Struct.new(:amount, :price_cents, keyword_init: true) do
    def self.bundles
      @bundles ||= [
        new(amount: 50,  price_cents: 2500),
        new(amount: 100, price_cents: 4500),
        new(amount: 200, price_cents: 8000)
      ].freeze
    end
  end
end
