# frozen_string_literal: true

require "test_helper"

module Platform
  class SpaceSubscriptionOverridesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @space = spaces(:one)
      @subscription = subscriptions(:one)  # essential, trialing, trial_ends_at: 14 days from now
    end

    # ── edit ─────────────────────────────────────────────────────────────────

    test "edit renders override form for super_admin" do
      sign_in @admin
      get edit_platform_space_subscription_override_path(@space)
      assert_response :success
    end

    test "edit is inaccessible to non-admin" do
      sign_in users(:manager)
      get edit_platform_space_subscription_override_path(@space)
      assert_redirected_to root_path
    end

    # ── extend_trial ─────────────────────────────────────────────────────────

    test "extend_trial extends trial_ends_at by given days" do
      sign_in @admin
      original_ends_at = @subscription.trial_ends_at

      patch platform_space_subscription_override_path(@space), params: {
        override_action: "extend_trial",
        days: 7
      }

      assert_redirected_to platform_space_path(@space)
      @subscription.reload
      assert_in_delta original_ends_at + 7.days, @subscription.trial_ends_at, 2.seconds
    end

    test "extend_trial logs a BillingEvent with actor_id" do
      sign_in @admin

      assert_difference "Billing::BillingEvent.count", 1 do
        patch platform_space_subscription_override_path(@space), params: {
          override_action: "extend_trial",
          days: 7
        }
      end

      event = Billing::BillingEvent.order(:created_at).last
      assert_equal "manual_override", event.event_type
      assert_equal @admin.id, event.actor_id
      assert_equal "extend_trial", event.metadata["action"]
    end

    test "extend_trial with invalid days redirects with error" do
      sign_in @admin

      patch platform_space_subscription_override_path(@space), params: {
        override_action: "extend_trial",
        days: 0
      }

      assert_redirected_to edit_platform_space_subscription_override_path(@space)
    end

    # ── change_plan ───────────────────────────────────────────────────────────

    test "change_plan updates plan_id and logs BillingEvent with actor_id" do
      sign_in @admin

      assert_difference "Billing::BillingEvent.count", 1 do
        patch platform_space_subscription_override_path(@space), params: {
          override_action: "change_plan",
          plan_id: "pro"
        }
      end

      assert_redirected_to platform_space_path(@space)
      assert_equal "pro", @subscription.reload.plan_id

      event = Billing::BillingEvent.order(:created_at).last
      assert_equal "manual_override", event.event_type
      assert_equal @admin.id, event.actor_id
      assert_equal "change_plan", event.metadata["action"]
    end

    # ── grant_credits ─────────────────────────────────────────────────────────

    test "grant_credits adds credits and redirects" do
      sign_in @admin
      credit = message_credits(:one)
      initial_balance = credit.balance

      patch platform_space_subscription_override_path(@space), params: {
        override_action: "grant_credits",
        amount: 25
      }

      assert_redirected_to platform_space_path(@space)
      assert_equal initial_balance + 25, credit.reload.balance
    end

    test "grant_credits with invalid amount redirects with error" do
      sign_in @admin

      patch platform_space_subscription_override_path(@space), params: {
        override_action: "grant_credits",
        amount: 0
      }

      assert_redirected_to edit_platform_space_subscription_override_path(@space)
    end

    test "unknown override_action redirects to space page" do
      sign_in @admin

      patch platform_space_subscription_override_path(@space), params: {
        override_action: "fly_to_mars"
      }

      assert_redirected_to platform_space_path(@space)
    end
  end
end
