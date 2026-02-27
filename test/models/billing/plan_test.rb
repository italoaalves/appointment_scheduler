# frozen_string_literal: true

require "test_helper"

module Billing
  class PlanTest < ActiveSupport::TestCase
    test "find returns starter plan" do
      plan = Billing::Plan.find("starter")
      assert_equal "starter", plan.id
    end

    test "find returns pro plan" do
      plan = Billing::Plan.find("pro")
      assert_equal "pro", plan.id
    end

    test "find raises ArgumentError for unknown plan" do
      assert_raises(ArgumentError) { Billing::Plan.find("bogus") }
    end

    test "all returns exactly 2 plans" do
      assert_equal 2, Billing::Plan.all.size
    end

    test "starter does not have personalized_booking_page feature" do
      refute Billing::Plan.starter.feature?(:personalized_booking_page)
    end

    test "pro has personalized_booking_page feature" do
      assert Billing::Plan.pro.feature?(:personalized_booking_page)
    end

    test "starter max_team_members is 1" do
      assert_equal 1, Billing::Plan.starter.limit(:max_team_members)
    end

    test "pro max_team_members is 5" do
      assert_equal 5, Billing::Plan.pro.limit(:max_team_members)
    end

    test "plans are frozen" do
      assert Billing::Plan.starter.frozen?
      assert Billing::Plan.pro.frozen?
    end

    test "starter max_customers is 100" do
      assert_equal 100, Billing::Plan.starter.limit(:max_customers)
    end

    test "pro max_customers is Float::INFINITY" do
      assert_equal Float::INFINITY, Billing::Plan.pro.limit(:max_customers)
    end

    test "starter whatsapp_monthly_quota is 0" do
      assert_equal 0, Billing::Plan.starter.whatsapp_monthly_quota
    end

    test "pro whatsapp_monthly_quota is 200" do
      assert_equal 200, Billing::Plan.pro.whatsapp_monthly_quota
    end

    test "starter does not have whatsapp_included_quota feature" do
      refute Billing::Plan.starter.feature?(:whatsapp_included_quota)
    end

    test "pro has whatsapp_included_quota and custom_appointment_policies features" do
      assert Billing::Plan.pro.feature?(:whatsapp_included_quota)
      assert Billing::Plan.pro.feature?(:custom_appointment_policies)
    end
  end
end
