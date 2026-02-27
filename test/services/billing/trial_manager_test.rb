# frozen_string_literal: true

require "test_helper"

module Billing
  class TrialManagerTest < ActiveSupport::TestCase
    # Use a fresh space with no subscription so each test starts clean
    setup do
      @space = Space.create!(name: "Trial Space #{SecureRandom.hex(4)}", timezone: "UTC")
    end

    # ── start_trial ───────────────────────────────────────────────────────────

    test "start_trial creates a subscription in trialing status" do
      sub = Billing::TrialManager.start_trial(@space)

      assert sub.persisted?
      assert sub.trialing?
      assert_equal "pro", sub.billing_plan.slug
    end

    test "start_trial sets trial_ends_at to 14 days from now" do
      freeze_time do
        sub = Billing::TrialManager.start_trial(@space)

        assert_in_delta 14.days.from_now.to_i, sub.trial_ends_at.to_i, 2
      end
    end

    test "start_trial sets current_period_start and current_period_end" do
      freeze_time do
        sub = Billing::TrialManager.start_trial(@space)

        assert_in_delta Time.current.to_i,           sub.current_period_start.to_i, 2
        assert_in_delta 14.days.from_now.to_i,       sub.current_period_end.to_i,   2
      end
    end

    test "start_trial creates a MessageCredit for the space" do
      Billing::TrialManager.start_trial(@space)

      credit = Billing::MessageCredit.find_by(space_id: @space.id)
      assert_not_nil credit
      assert_equal 0,   credit.balance
      assert_equal 200, credit.monthly_quota_remaining
    end

    test "start_trial logs a subscription.created BillingEvent" do
      assert_difference -> { Billing::BillingEvent.where(event_type: "subscription.created").count } do
        Billing::TrialManager.start_trial(@space)
      end

      event = Billing::BillingEvent.where(space_id: @space.id, event_type: "subscription.created").last
      assert_equal "pro", event.metadata["plan_slug"]
      assert event.metadata["trial_ends_at"].present?
    end

    test "start_trial is idempotent — second call returns existing subscription" do
      first  = Billing::TrialManager.start_trial(@space)
      second = Billing::TrialManager.start_trial(@space)

      assert_equal first.id, second.id
      assert_equal 1, Billing::Subscription.where(space_id: @space.id).count
    end

    test "start_trial idempotency does not create duplicate MessageCredit" do
      Billing::TrialManager.start_trial(@space)

      assert_no_difference -> { Billing::MessageCredit.where(space_id: @space.id).count } do
        Billing::TrialManager.start_trial(@space)
      end
    end

    # ── expire_trial ──────────────────────────────────────────────────────────

    test "expire_trial transitions trialing subscription to expired when past trial_ends_at" do
      sub = Billing::TrialManager.start_trial(@space)
      sub.update_column(:trial_ends_at, 1.minute.ago)

      result = Billing::TrialManager.expire_trial(sub)

      assert result
      assert sub.reload.expired?
    end

    test "expire_trial logs a trial.expired BillingEvent" do
      sub = Billing::TrialManager.start_trial(@space)
      sub.update_column(:trial_ends_at, 1.minute.ago)

      assert_difference -> { Billing::BillingEvent.where(event_type: "trial.expired").count } do
        Billing::TrialManager.expire_trial(sub)
      end
    end

    test "expire_trial returns false and does nothing when subscription is active" do
      sub = Billing::TrialManager.start_trial(@space)
      sub.update_column(:status, Billing::Subscription.statuses[:active])

      result = Billing::TrialManager.expire_trial(sub)

      assert_equal false, result
      assert sub.reload.active?
    end

    test "expire_trial returns false when trial_ends_at is in the future" do
      sub = Billing::TrialManager.start_trial(@space)
      # trial_ends_at is already 14 days from now

      result = Billing::TrialManager.expire_trial(sub)

      assert_equal false, result
      assert sub.reload.trialing?
    end

    test "expire_trial returns false when trial_ends_at is nil" do
      sub = Billing::TrialManager.start_trial(@space)
      sub.update_column(:trial_ends_at, nil)

      result = Billing::TrialManager.expire_trial(sub)

      assert_equal false, result
    end
  end
end
