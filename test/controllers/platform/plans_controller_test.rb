# frozen_string_literal: true

require "test_helper"

module Platform
  class PlansControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @manager = users(:manager)
      @essential = billing_plans(:essential)
      @pro = billing_plans(:pro)
    end

    # ── auth ──────────────────────────────────────────────────────────────

    test "unauthenticated user is redirected to login" do
      get platform_plans_path
      assert_redirected_to new_user_session_path
    end

    test "non-admin is redirected to root" do
      sign_in @manager
      get platform_plans_path
      assert_redirected_to root_path
    end

    # ── index ─────────────────────────────────────────────────────────────

    test "admin can list plans" do
      sign_in @admin
      get platform_plans_path
      assert_response :success
    end

    # ── new ───────────────────────────────────────────────────────────────

    test "admin sees new plan form" do
      sign_in @admin
      get new_platform_plan_path
      assert_response :success
    end

    # ── create ────────────────────────────────────────────────────────────

    test "admin can create a plan" do
      sign_in @admin

      assert_difference "Billing::Plan.count", 1 do
        post platform_plans_path, params: {
          billing_plan: {
            name: "Starter",
            slug: "starter",
            price_cents: 2999,
            position: 0,
            active: true,
            public: true,
            highlighted: false,
            trial_default: false,
            features: [ "" ],
            allowed_payment_methods: [ "" ]
          }
        }
      end

      assert_redirected_to platform_plans_path
      plan = Billing::Plan.find_by!(slug: "starter")
      assert_equal "Starter", plan.name
      assert_equal 2999, plan.price_cents
    end

    test "create with blank limits saves nil for unlimited" do
      sign_in @admin

      post platform_plans_path, params: {
        billing_plan: {
          name: "Unlimited",
          slug: "unlimited_test",
          price_cents: 9999,
          position: 10,
          max_team_members: "",
          max_customers: "",
          max_scheduling_links: "",
          whatsapp_monthly_quota: "",
          features: [ "" ],
          allowed_payment_methods: [ "" ]
        }
      }

      plan = Billing::Plan.find_by!(slug: "unlimited_test")
      assert_nil plan.max_team_members
      assert_nil plan.max_customers
      assert_nil plan.max_scheduling_links
      assert_nil plan.whatsapp_monthly_quota
    end

    test "create with invalid params re-renders new" do
      sign_in @admin

      assert_no_difference "Billing::Plan.count" do
        post platform_plans_path, params: {
          billing_plan: {
            name: "",
            slug: "bad",
            price_cents: 100,
            position: 0,
            features: [ "" ],
            allowed_payment_methods: [ "" ]
          }
        }
      end

      assert_response :unprocessable_entity
    end

    # ── edit ──────────────────────────────────────────────────────────────

    test "admin can see edit form" do
      sign_in @admin
      get edit_platform_plan_path(@essential)
      assert_response :success
    end

    # ── update ────────────────────────────────────────────────────────────

    test "admin can update a plan" do
      sign_in @admin

      patch platform_plan_path(@essential), params: {
        billing_plan: { name: "Essential Plus" }
      }

      assert_redirected_to platform_plans_path
      assert_equal "Essential Plus", @essential.reload.name
    end

    test "slug is immutable on update" do
      sign_in @admin

      patch platform_plan_path(@essential), params: {
        billing_plan: { slug: "hacked_slug", name: "Still Essential" }
      }

      assert_redirected_to platform_plans_path
      assert_equal "essential", @essential.reload.slug
      assert_equal "Still Essential", @essential.name
    end

    test "update with invalid params re-renders edit" do
      sign_in @admin

      patch platform_plan_path(@essential), params: {
        billing_plan: { name: "", price_cents: -1 }
      }

      assert_response :unprocessable_entity
    end

    # ── trial_default toggling ────────────────────────────────────────────

    test "setting trial_default unsets the previous default" do
      sign_in @admin

      assert @pro.trial_default?, "Pro should be trial default in fixtures"
      refute @essential.trial_default?

      patch platform_plan_path(@essential), params: {
        billing_plan: { trial_default: true }
      }

      assert_redirected_to platform_plans_path
      assert @essential.reload.trial_default?
      refute @pro.reload.trial_default?
    end

    # ── features & payment methods ────────────────────────────────────────

    test "create with features saves JSONB array" do
      sign_in @admin

      post platform_plans_path, params: {
        billing_plan: {
          name: "Feature Plan",
          slug: "feature_plan",
          price_cents: 5000,
          position: 99,
          features: [ "personalized_booking_page", "priority_support" ],
          allowed_payment_methods: [ "credit_card" ]
        }
      }

      plan = Billing::Plan.find_by!(slug: "feature_plan")
      assert_includes plan.features, "personalized_booking_page"
      assert_includes plan.features, "priority_support"
      assert_equal [ "credit_card" ], plan.allowed_payment_methods
    end
  end
end
