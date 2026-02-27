# frozen_string_literal: true

require "test_helper"

module Billing
  class PlanTest < ActiveSupport::TestCase
    # ── Validations ───────────────────────────────────────────────────────────

    test "valid plan saves successfully" do
      plan = Billing::Plan.new(
        slug: "test_plan", name: "Test", price_cents: 0, position: 99
      )
      assert plan.valid?
    end

    test "slug is required" do
      plan = Billing::Plan.new(name: "Test", price_cents: 0, position: 1)
      assert_not plan.valid?
      assert plan.errors[:slug].any?
    end

    test "slug must be unique" do
      plan = Billing::Plan.new(
        slug: billing_plans(:pro).slug, name: "Dup", price_cents: 0, position: 99
      )
      assert_not plan.valid?
      assert plan.errors[:slug].any?
    end

    test "slug must match [a-z0-9_]+" do
      plan = Billing::Plan.new(slug: "Bad Slug!", name: "X", price_cents: 0, position: 1)
      assert_not plan.valid?
      assert plan.errors[:slug].any?
    end

    test "name is required" do
      plan = Billing::Plan.new(slug: "x", price_cents: 0, position: 1)
      assert_not plan.valid?
      assert plan.errors[:name].any?
    end

    test "price_cents cannot be negative" do
      plan = Billing::Plan.new(slug: "x", name: "X", price_cents: -1, position: 1)
      assert_not plan.valid?
      assert plan.errors[:price_cents].any?
    end

    test "position is required" do
      plan = Billing::Plan.new(slug: "x", name: "X", price_cents: 0, position: nil)
      assert_not plan.valid?
      assert plan.errors[:position].any?
    end

    # ── Scopes ────────────────────────────────────────────────────────────────

    test "active scope returns only active plans" do
      slugs = Billing::Plan.active.pluck(:slug)
      assert_includes slugs, "essential"
      assert_includes slugs, "pro"
      assert_includes slugs, "enterprise"
    end

    test "visible scope returns public active plans ordered by position" do
      visible = Billing::Plan.visible
      assert visible.all?(&:public)
      assert visible.all?(&:active)
      positions = visible.map(&:position)
      assert_equal positions.sort, positions
    end

    # ── #free? ────────────────────────────────────────────────────────────────

    test "free? returns true when price_cents is 0" do
      plan = Billing::Plan.new(price_cents: 0)
      assert plan.free?
    end

    test "free? returns false for paid plan" do
      assert_not billing_plans(:essential).free?
    end

    # ── #feature? ────────────────────────────────────────────────────────────

    test "essential does not have personalized_booking_page" do
      refute billing_plans(:essential).feature?("personalized_booking_page")
      refute billing_plans(:essential).feature?(:personalized_booking_page)
    end

    test "pro has personalized_booking_page" do
      assert billing_plans(:pro).feature?("personalized_booking_page")
      assert billing_plans(:pro).feature?(:personalized_booking_page)
    end

    test "enterprise has priority_support" do
      assert billing_plans(:enterprise).feature?(:priority_support)
    end

    test "essential does not have priority_support" do
      refute billing_plans(:essential).feature?(:priority_support)
    end

    # ── #limit_reached? ───────────────────────────────────────────────────────

    test "limit_reached? returns false when limit is nil (unlimited)" do
      refute billing_plans(:pro).limit_reached?(:max_customers, 99_999)
    end

    test "limit_reached? returns false when count is below limit" do
      refute billing_plans(:essential).limit_reached?(:max_customers, 50)
    end

    test "limit_reached? returns true when count equals limit" do
      assert billing_plans(:essential).limit_reached?(:max_customers, 100)
    end

    test "limit_reached? returns true when count exceeds limit" do
      assert billing_plans(:essential).limit_reached?(:max_customers, 101)
    end

    # ── #whatsapp_unlimited? ──────────────────────────────────────────────────

    test "enterprise whatsapp_unlimited? returns true" do
      assert billing_plans(:enterprise).whatsapp_unlimited?
    end

    test "pro whatsapp_unlimited? returns false" do
      refute billing_plans(:pro).whatsapp_unlimited?
    end

    test "essential whatsapp_unlimited? returns false" do
      refute billing_plans(:essential).whatsapp_unlimited?
    end

    # ── #requires_payment_method? ─────────────────────────────────────────────

    test "plan with empty allowed_payment_methods allows any method" do
      assert billing_plans(:essential).requires_payment_method?("pix")
      assert billing_plans(:essential).requires_payment_method?("credit_card")
    end

    test "enterprise requires credit_card only" do
      assert billing_plans(:enterprise).requires_payment_method?("credit_card")
      assert_not billing_plans(:enterprise).requires_payment_method?("pix")
    end

    # ── .trial_plan ───────────────────────────────────────────────────────────

    test "trial_plan returns the plan with trial_default true" do
      assert_equal billing_plans(:pro).id, Billing::Plan.trial_plan.id
    end

    test "trial_plan raises when no trial plan exists" do
      Billing::Plan.update_all(trial_default: false)
      assert_raises(ActiveRecord::RecordNotFound) { Billing::Plan.trial_plan }
    end

    # ── .find_by_slug! ────────────────────────────────────────────────────────

    test "find_by_slug! returns the correct plan" do
      plan = Billing::Plan.find_by_slug!("essential")
      assert_equal "essential", plan.slug
    end

    test "find_by_slug! raises for unknown slug" do
      assert_raises(ActiveRecord::RecordNotFound) { Billing::Plan.find_by_slug!("bogus") }
    end

    # ── .find with integer id ─────────────────────────────────────────────────

    test "find with integer id works normally" do
      plan = Billing::Plan.find(billing_plans(:pro).id)
      assert_equal "pro", plan.slug
    end

    # ── KNOWN_FEATURES ────────────────────────────────────────────────────────

    test "KNOWN_FEATURES is a frozen array of strings" do
      assert_kind_of Array, Billing::Plan::KNOWN_FEATURES
      assert Billing::Plan::KNOWN_FEATURES.frozen?
      assert Billing::Plan::KNOWN_FEATURES.all? { |f| f.is_a?(String) }
    end

    test "KNOWN_FEATURES includes expected feature flags" do
      %w[personalized_booking_page custom_appointment_policies
         whatsapp_included_quota priority_support].each do |f|
        assert_includes Billing::Plan::KNOWN_FEATURES, f
      end
    end
  end
end
