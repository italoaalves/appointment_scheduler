# frozen_string_literal: true

require "test_helper"

module Spaces
  class CustomersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager_starter = users(:manager)      # spaces(:one) — Starter plan, max 100 customers
      @manager_pro     = users(:manager_two)  # spaces(:two) — Pro plan, unlimited
    end

    # ── Starter plan — at customer limit ─────────────────────────────────────

    test "POST create redirects with limit alert when Starter plan is at 100 customers" do
      sign_in @manager_starter
      space = spaces(:one)
      Customer.insert_all(
        (100 - space.customers.count).times.map { |i|
          { space_id: space.id, name: "Cust #{i}", created_at: Time.current, updated_at: Time.current }
        }
      )

      post customers_url, params: { customer: { name: "Over Limit", phone: "+5511999999999" } }

      assert_redirected_to customers_url
      assert_equal I18n.t("billing.limits.customers_exceeded"), flash[:alert]
    end

    # ── Pro plan — unlimited ──────────────────────────────────────────────────

    test "POST create succeeds when Pro plan has no customer limit" do
      sign_in @manager_pro

      assert_difference "Customer.count", 1 do
        post customers_url, params: {
          customer: { name: "New Customer", phone: "+5511999000001" }
        }
      end

      assert_response :redirect
      assert_not_equal I18n.t("billing.limits.customers_exceeded"), flash[:alert]
    end
  end
end
