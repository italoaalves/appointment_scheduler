# frozen_string_literal: true

module Billing
  class PlanEnforcer
    def self.can?(space, action)
      new(space).can?(action)
    end

    def self.limit_for(space, attribute)
      new(space).limit_for(attribute)
    end

    def initialize(space)
      @space = space
    end

    def can?(action)
      subscription = Current.subscription || @space.subscription
      plan = subscription&.plan || Billing::Plan::STARTER

      return false if subscription&.expired?

      case action
      when :create_team_member
        @space.space_memberships.count < plan.max_team_members
      when :create_customer
        @space.customers.count < plan.max_customers
      when :create_scheduling_link
        @space.scheduling_links.count < plan.max_scheduling_links
      when :access_personalized_booking_page
        plan.feature?(:personalized_booking_page)
      when :access_custom_policies
        plan.feature?(:custom_appointment_policies)
      when :send_whatsapp
        return false unless plan.feature?(:whatsapp_included_quota) || plan.whatsapp_monthly_quota.positive?
        credit = Billing::MessageCredit.find_by(space_id: @space.id)
        credit.present? && (credit.balance + credit.monthly_quota_remaining) > 0
      else
        false
      end
    end

    def limit_for(attribute)
      subscription = Current.subscription || @space.subscription
      plan = subscription&.plan || Billing::Plan::STARTER
      plan.limit(attribute)
    end
  end
end
