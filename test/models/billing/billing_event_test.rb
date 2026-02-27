# frozen_string_literal: true

require "test_helper"

module Billing
  class BillingEventTest < ActiveSupport::TestCase
    def valid_attrs
      {
        space: spaces(:one),
        subscription: subscriptions(:one),
        event_type: "subscription.created"
      }
    end

    test "new billing event can be created" do
      event = Billing::BillingEvent.create!(valid_attrs)
      assert event.persisted?
    end

    test "event_type is required" do
      event = Billing::BillingEvent.new(valid_attrs.merge(event_type: nil))
      assert_not event.valid?
      assert event.errors[:event_type].any?
    end

    test "subscription is optional" do
      event = Billing::BillingEvent.new(valid_attrs.except(:subscription))
      assert event.valid?
    end

    test "persisted events are readonly — update raises ActiveRecord::ReadOnlyRecord" do
      event = billing_events(:one)
      assert_raises(ActiveRecord::ReadOnlyRecord) do
        event.update!(event_type: "plan.changed")
      end
    end

    test "persisted events are readonly — save raises ActiveRecord::ReadOnlyRecord" do
      event = billing_events(:one)
      event.event_type = "plan.changed"
      assert_raises(ActiveRecord::ReadOnlyRecord) { event.save! }
    end

    test "metadata defaults to empty hash" do
      event = Billing::BillingEvent.create!(valid_attrs)
      assert_equal({}, event.metadata)
    end

    test "metadata can store arbitrary JSON" do
      event = Billing::BillingEvent.create!(
        valid_attrs.merge(metadata: { plan_from: "starter", plan_to: "pro" })
      )
      assert_equal "starter", event.metadata["plan_from"]
    end
  end
end
