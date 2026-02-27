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
      plan = subscription&.plan || default_plan

      return false if subscription&.expired?

      case action
      when :create_team_member
        max = plan.max_team_members
        max.nil? || @space.space_memberships.count < max
      when :create_customer
        max = plan.max_customers
        max.nil? || @space.customers.count < max
      when :create_scheduling_link
        max = plan.max_scheduling_links
        max.nil? || @space.scheduling_links.count < max
      when :access_personalized_booking_page
        plan.feature?(:personalized_booking_page)
      when :access_custom_policies
        plan.feature?(:custom_appointment_policies)
      when :send_whatsapp
        return true if plan.whatsapp_unlimited?
        return false unless plan.feature?(:whatsapp_included_quota) || plan.whatsapp_monthly_quota.to_i.positive?
        credit = Billing::MessageCredit.find_by(space_id: @space.id)
        credit.present? && (credit.balance + credit.monthly_quota_remaining) > 0
      else
        false
      end
    end

    def limit_for(attribute)
      subscription = Current.subscription || @space.subscription
      plan = subscription&.plan || default_plan
      plan.limit(attribute)
    end

    private

    def default_plan
      @default_plan ||= Billing::Plan.active.order(:price_cents).first
    end
  end
end
