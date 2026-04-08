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

    # ── Destroy with active appointments ──────────────────────────────────────

    test "DELETE destroy redirects with alert when customer has active appointments" do
      sign_in @manager_starter
      customer = customers(:one)
      appointments(:one).update!(customer: customer, status: :confirmed)
      assert customer.appointments.where(status: Appointment::SLOT_BLOCKING_STATUSES).any?

      assert_no_difference "Customer.count" do
        delete customer_url(customer)
      end

      assert_redirected_to customer_path(customer)
      assert flash[:alert].present?
      assert_includes flash[:alert], "1"
    end

    # ── Pro plan — unlimited ──────────────────────────────────────────────────

    test "POST create succeeds when Pro plan has no customer limit" do
      sign_in @manager_pro

      assert_difference "Customer.count", 1 do
        post customers_url, params: {
          customer: { name: "New Customer", phone: "+5511999000001", whatsapp_opt_in: "0" }
        }
      end

      assert_response :redirect
      assert_not_equal I18n.t("billing.limits.customers_exceeded"), flash[:alert]
    end

    test "POST create stores whatsapp consent when checked" do
      sign_in @manager_pro

      freeze_time do
        assert_difference "Customer.count", 1 do
          post customers_url, params: {
            customer: {
              name: "WhatsApp Consent Customer",
              phone: "+5511999000002",
              whatsapp_opt_in: "1"
            }
          }
        end

        customer = Customer.order(:id).last
        assert customer.whatsapp_opted_in?
        assert_equal Time.current, customer.whatsapp_opted_in_at
        assert_equal "staff_entry", customer.whatsapp_opt_in_source
      end
    end

    test "PATCH update revokes whatsapp consent when unchecked" do
      sign_in @manager_starter
      customer = customers(:one)
      customer.update!(
        whatsapp_opted_in_at: 2.days.ago,
        whatsapp_opt_in_source: "booking_form"
      )

      freeze_time do
        patch customer_url(customer), params: {
          customer: {
            name: customer.name,
            phone: customer.phone,
            email: customer.email,
            address: customer.address,
            whatsapp_opt_in: "0"
          }
        }

        assert_redirected_to customer_url(customer)
        customer.reload
        assert_not customer.whatsapp_opted_in?
        assert_equal Time.current, customer.whatsapp_opted_out_at
        assert_equal "staff_entry", customer.whatsapp_opt_out_source
      end
    end
  end
end
