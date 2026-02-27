# frozen_string_literal: true

module Billing
  class Plan
    attr_reader :id, :name, :price_cents, :max_team_members, :max_customers,
                :max_scheduling_links, :features, :whatsapp_monthly_quota

    def initialize(id:, name:, price_cents:, max_team_members:, max_customers:,
                   max_scheduling_links:, features:, whatsapp_monthly_quota:)
      @id                    = id
      @name                  = name
      @price_cents           = price_cents
      @max_team_members      = max_team_members
      @max_customers         = max_customers
      @max_scheduling_links  = max_scheduling_links
      @features              = Set.new(features).freeze
      @whatsapp_monthly_quota = whatsapp_monthly_quota
      freeze
    end

    def feature?(flag)
      features.include?(flag)
    end

    def limit(attribute)
      public_send(attribute)
    end

    STARTER = new(
      id:                    "starter",
      name:                  "Starter",
      price_cents:           0,
      max_team_members:      1,
      max_customers:         100,
      max_scheduling_links:  3,
      features:              [],
      whatsapp_monthly_quota: 0
    ).freeze

    PRO = new(
      id:                    "pro",
      name:                  "Pro",
      price_cents:           0,
      max_team_members:      5,
      max_customers:         Float::INFINITY,
      max_scheduling_links:  Float::INFINITY,
      features:              %i[personalized_booking_page whatsapp_included_quota custom_appointment_policies],
      whatsapp_monthly_quota: 200
    ).freeze

    ALL = { "starter" => STARTER, "pro" => PRO }.freeze

    def self.starter
      STARTER
    end

    def self.pro
      PRO
    end

    def self.find(id)
      ALL.fetch(id) { raise ArgumentError, "Unknown plan: #{id.inspect}" }
    end

    def self.all
      ALL.values
    end
  end
end
