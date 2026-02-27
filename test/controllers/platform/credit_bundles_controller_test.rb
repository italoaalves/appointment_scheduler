# frozen_string_literal: true

require "test_helper"

module Platform
  class CreditBundlesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin   = users(:admin)
      @manager = users(:manager)
      @bundle  = credit_bundles(:fifty)
    end

    # ── auth ──────────────────────────────────────────────────────────────

    test "unauthenticated user is redirected to login" do
      get platform_credit_bundles_path
      assert_redirected_to new_user_session_path
    end

    test "non-admin is redirected to root" do
      sign_in @manager
      get platform_credit_bundles_path
      assert_redirected_to root_path
    end

    # ── index ─────────────────────────────────────────────────────────────

    test "admin can list credit bundles" do
      sign_in @admin
      get platform_credit_bundles_path
      assert_response :success
    end

    # ── new ───────────────────────────────────────────────────────────────

    test "admin sees new bundle form" do
      sign_in @admin
      get new_platform_credit_bundle_path
      assert_response :success
    end

    # ── create ────────────────────────────────────────────────────────────

    test "admin can create a credit bundle" do
      sign_in @admin

      assert_difference "Billing::CreditBundle.count", 1 do
        post platform_credit_bundles_path, params: {
          credit_bundle: {
            name: "500 credits",
            amount: 500,
            price_cents: 15000,
            position: 3,
            active: true
          }
        }
      end

      assert_redirected_to platform_credit_bundles_path
      bundle = Billing::CreditBundle.find_by!(name: "500 credits")
      assert_equal 500,   bundle.amount
      assert_equal 15000, bundle.price_cents
    end

    test "create with invalid params re-renders new" do
      sign_in @admin

      assert_no_difference "Billing::CreditBundle.count" do
        post platform_credit_bundles_path, params: {
          credit_bundle: { name: "", amount: 0, price_cents: 0, position: 0 }
        }
      end

      assert_response :unprocessable_entity
    end

    # ── edit ──────────────────────────────────────────────────────────────

    test "admin can see edit form" do
      sign_in @admin
      get edit_platform_credit_bundle_path(@bundle)
      assert_response :success
    end

    # ── update ────────────────────────────────────────────────────────────

    test "admin can update a credit bundle" do
      sign_in @admin

      patch platform_credit_bundle_path(@bundle), params: {
        credit_bundle: { name: "55 credits", price_cents: 2750 }
      }

      assert_redirected_to platform_credit_bundles_path
      @bundle.reload
      assert_equal "55 credits", @bundle.name
      assert_equal 2750, @bundle.price_cents
    end

    test "update with invalid params re-renders edit" do
      sign_in @admin

      patch platform_credit_bundle_path(@bundle), params: {
        credit_bundle: { name: "", amount: -1 }
      }

      assert_response :unprocessable_entity
    end

    test "deactivating a bundle removes it from available scope" do
      sign_in @admin

      patch platform_credit_bundle_path(@bundle), params: {
        credit_bundle: { active: false }
      }

      assert_redirected_to platform_credit_bundles_path
      refute Billing::CreditBundle.available.include?(@bundle.reload)
    end
  end
end
