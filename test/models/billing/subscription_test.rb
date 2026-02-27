# frozen_string_literal: true

require "test_helper"

module Billing
  class SubscriptionTest < ActiveSupport::TestCase
    def valid_attrs
      {
        space: spaces(:one),
        plan_id: "starter",
        status: :trialing,
        trial_ends_at: 14.days.from_now
      }
    end

    test "valid subscription can be created" do
      sub = Billing::Subscription.new(valid_attrs)
      assert sub.valid?
    end

    test "plan_id validates inclusion — rejects bogus" do
      sub = Billing::Subscription.new(valid_attrs.merge(plan_id: "bogus"))
      assert_not sub.valid?
      assert_includes sub.errors[:plan_id], I18n.t("errors.messages.inclusion")
    end

    test "plan_id is required" do
      sub = Billing::Subscription.new(valid_attrs.merge(plan_id: nil))
      assert_not sub.valid?
      assert sub.errors[:plan_id].any?
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
      assert_equal "starter", sub.plan.id
    end

    test "#plan returns pro plan for pro subscription" do
      sub = subscriptions(:two)
      assert_equal "pro", sub.plan.id
    end
  end
end
