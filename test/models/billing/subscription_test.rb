# frozen_string_literal: true

require "test_helper"

module Billing
  class SubscriptionTest < ActiveSupport::TestCase
    def valid_attrs
      {
        space:         spaces(:one),
        billing_plan:  billing_plans(:essential),
        status:        :trialing,
        trial_ends_at: 14.days.from_now
      }
    end

    test "valid subscription can be created" do
      sub = Billing::Subscription.new(valid_attrs)
      assert sub.valid?
    end

    test "billing_plan is required" do
      sub = Billing::Subscription.new(valid_attrs.merge(billing_plan: nil))
      assert_not sub.valid?
      assert sub.errors[:billing_plan].any?
    end

    test "status enum resolves trialing" do
      sub = Billing::Subscription.new(valid_attrs.merge(status: :trialing))
      assert sub.trialing?
    end

    test "status enum resolves active" do
      sub = Billing::Subscription.new(valid_attrs.merge(status: :active))
      assert sub.active?
    end

    test "#plan returns the Billing::Plan object" do
      sub = subscriptions(:one)
      assert_instance_of Billing::Plan, sub.plan
      assert_equal "essential", sub.plan.slug
    end

    test "#plan returns pro plan for pro subscription" do
      sub = subscriptions(:two)
      assert_equal "pro", sub.plan.slug
    end
  end
end
