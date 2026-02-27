# frozen_string_literal: true

require "test_helper"

module Billing
  class PlanEnforcerTest < ActiveSupport::TestCase
    # ── Helpers ───────────────────────────────────────────────────────────────

    def make_space(plan_id:, status: :trialing)
      space = Space.create!(name: "Enforcer Space #{SecureRandom.hex(4)}", timezone: "UTC")
      Billing::BillingEvent.where(space_id: space.id).delete_all
      Billing::MessageCredit.where(space_id: space.id).delete_all

      unless status == :no_subscription
        Billing::Subscription.create!(
          space_id: space.id,
          plan_id:  plan_id,
          status:   Billing::Subscription.statuses[status]
        )
        space.reload  # clear has_one :subscription cache
      end
      space
    end

    # ── No subscription — defaults to Essential ────────────────────────────────

    test "no subscription treats space as Essential (create_team_member with 1 member returns false)" do
      space = make_space(plan_id: "essential", status: :no_subscription)
      SpaceMembership.create!(space: space, user: users(:manager))

      assert_not Billing::PlanEnforcer.can?(space, :create_team_member)
    end

    test "no subscription treats space as Essential (create_customer with 0 returns true)" do
      space = make_space(plan_id: "essential", status: :no_subscription)

      assert Billing::PlanEnforcer.can?(space, :create_customer)
    end

    test "no subscription treats space as Essential (access_personalized_booking_page returns false)" do
      space = make_space(plan_id: "essential", status: :no_subscription)

      assert_not Billing::PlanEnforcer.can?(space, :access_personalized_booking_page)
    end

    # ── Expired subscription ──────────────────────────────────────────────────

    test "expired subscription returns false for all actions" do
      space = make_space(plan_id: "pro", status: :expired)

      assert_not Billing::PlanEnforcer.can?(space, :create_team_member)
      assert_not Billing::PlanEnforcer.can?(space, :create_customer)
      assert_not Billing::PlanEnforcer.can?(space, :access_personalized_booking_page)
      assert_not Billing::PlanEnforcer.can?(space, :send_whatsapp)
    end

    # ── :create_team_member ───────────────────────────────────────────────────

    test "Essential with 1 team member: create_team_member returns false (max is 1)" do
      space = make_space(plan_id: "essential")
      SpaceMembership.create!(space: space, user: users(:manager))

      assert_not Billing::PlanEnforcer.can?(space, :create_team_member)
    end

    test "Essential with 0 team members: create_team_member returns true (count 0 < max 1)" do
      space = make_space(plan_id: "essential")

      assert Billing::PlanEnforcer.can?(space, :create_team_member)
    end

    test "Pro with 4 team members: create_team_member returns true" do
      space = make_space(plan_id: "pro", status: :active)
      SpaceMembership.create!(space: space, user: users(:manager))
      SpaceMembership.create!(space: space, user: users(:secretary))
      SpaceMembership.create!(space: space, user: users(:manager_two))
      SpaceMembership.create!(space: space, user: users(:admin))

      assert Billing::PlanEnforcer.can?(space, :create_team_member)
    end

    test "Pro with 5 team members: create_team_member returns false" do
      space = make_space(plan_id: "pro", status: :active)
      SpaceMembership.create!(space: space, user: users(:manager))
      SpaceMembership.create!(space: space, user: users(:secretary))
      SpaceMembership.create!(space: space, user: users(:manager_two))
      SpaceMembership.create!(space: space, user: users(:admin))

      extra = User.create!(
        email:    "extra_#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        name:     "Extra",
        role:     ""
      )
      SpaceMembership.create!(space: space, user: extra)

      assert_not Billing::PlanEnforcer.can?(space, :create_team_member)
    end

    # ── :create_customer ──────────────────────────────────────────────────────

    test "Essential with 0 customers: create_customer returns true" do
      space = make_space(plan_id: "essential")

      assert Billing::PlanEnforcer.can?(space, :create_customer)
    end

    test "Essential with 100 customers: create_customer returns false" do
      space = make_space(plan_id: "essential")
      Customer.insert_all(
        100.times.map { |i| { space_id: space.id, name: "Customer #{i}", created_at: Time.current, updated_at: Time.current } }
      )

      assert_not Billing::PlanEnforcer.can?(space, :create_customer)
    end

    test "Pro with 100 customers: create_customer returns true (unlimited)" do
      space = make_space(plan_id: "pro", status: :active)
      Customer.insert_all(
        100.times.map { |i| { space_id: space.id, name: "Cust #{i}", created_at: Time.current, updated_at: Time.current } }
      )

      assert Billing::PlanEnforcer.can?(space, :create_customer)
    end

    # ── :access_personalized_booking_page ────────────────────────────────────

    test "Essential plan: access_personalized_booking_page returns false" do
      space = make_space(plan_id: "essential")

      assert_not Billing::PlanEnforcer.can?(space, :access_personalized_booking_page)
    end

    test "Pro plan: access_personalized_booking_page returns true" do
      space = make_space(plan_id: "pro", status: :active)

      assert Billing::PlanEnforcer.can?(space, :access_personalized_booking_page)
    end

    # ── :access_custom_policies ───────────────────────────────────────────────

    test "Essential plan: access_custom_policies returns false" do
      space = make_space(plan_id: "essential")

      assert_not Billing::PlanEnforcer.can?(space, :access_custom_policies)
    end

    test "Pro plan: access_custom_policies returns true" do
      space = make_space(plan_id: "pro", status: :active)

      assert Billing::PlanEnforcer.can?(space, :access_custom_policies)
    end

    # ── :send_whatsapp ────────────────────────────────────────────────────────

    test "send_whatsapp returns false when no MessageCredit record" do
      space = make_space(plan_id: "pro", status: :active)

      assert_not Billing::PlanEnforcer.can?(space, :send_whatsapp)
    end

    test "send_whatsapp returns false when balance and quota are both zero" do
      space = make_space(plan_id: "pro", status: :active)
      Billing::MessageCredit.create!(space: space, balance: 0, monthly_quota_remaining: 0)

      assert_not Billing::PlanEnforcer.can?(space, :send_whatsapp)
    end

    test "send_whatsapp returns true when balance > 0" do
      space = make_space(plan_id: "pro", status: :active)
      Billing::MessageCredit.create!(space: space, balance: 10, monthly_quota_remaining: 0)

      assert Billing::PlanEnforcer.can?(space, :send_whatsapp)
    end

    test "send_whatsapp returns true when monthly_quota_remaining > 0" do
      space = make_space(plan_id: "pro", status: :active)
      Billing::MessageCredit.create!(space: space, balance: 0, monthly_quota_remaining: 50)

      assert Billing::PlanEnforcer.can?(space, :send_whatsapp)
    end

    # ── limit_for ─────────────────────────────────────────────────────────────

    test "limit_for returns the plan's max_team_members" do
      space = make_space(plan_id: "essential")

      assert_equal 1, Billing::PlanEnforcer.limit_for(space, :max_team_members)
    end

    test "limit_for returns nil for Pro max_customers (unlimited)" do
      space = make_space(plan_id: "pro", status: :active)

      assert_nil Billing::PlanEnforcer.limit_for(space, :max_customers)
    end

    test "limit_for returns Essential limits when no subscription" do
      space = make_space(plan_id: "essential", status: :no_subscription)

      assert_equal 1,   Billing::PlanEnforcer.limit_for(space, :max_team_members)
      assert_equal 100, Billing::PlanEnforcer.limit_for(space, :max_customers)
    end

    # ── Unknown action ────────────────────────────────────────────────────────

    test "unknown action returns false" do
      space = make_space(plan_id: "pro", status: :active)

      assert_not Billing::PlanEnforcer.can?(space, :fly_to_the_moon)
    end
  end
end
