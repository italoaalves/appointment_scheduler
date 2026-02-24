# frozen_string_literal: true

require "test_helper"

module Admin
  class CustomersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager = users(:manager)
      @secretary = users(:secretary)
      @admin = users(:admin)
      @customer = customers(:one)
    end

    test "redirects unauthenticated to login" do
      get admin_customers_url
      assert_redirected_to new_user_session_url
    end

    test "redirects admin role to root" do
      sign_in @admin
      get admin_customers_url
      assert_redirected_to root_url
    end

    test "manager can get index" do
      sign_in @manager
      get admin_customers_url
      assert_response :success
    end

    test "secretary can get index" do
      sign_in @secretary
      get admin_customers_url
      assert_response :success
    end

    test "index shows only current tenant customers" do
      sign_in @manager
      get admin_customers_url
      assert_response :success
      assert_select "table tbody tr", count: 2 # one and two, not other_space_customer
    end

    test "manager can create customer" do
      sign_in @manager
      assert_difference "Customer.count", 1 do
        post admin_customers_url, params: {
          customer: { name: "New Customer", phone: "+5511555555555", address: "Rua X" }
        }
      end
      assert_redirected_to admin_customer_url(Customer.last)
      assert_equal @manager.space_id, Customer.last.space_id
    end

    test "manager can update customer" do
      sign_in @manager
      patch admin_customer_url(@customer), params: {
        customer: { name: "Updated Name", phone: @customer.phone }
      }
      assert_redirected_to admin_customer_url(@customer)
      @customer.reload
      assert_equal "Updated Name", @customer.name
    end

    test "manager can destroy customer" do
      sign_in @manager
      assert_difference "Customer.count", -1 do
        delete admin_customer_url(@customer)
      end
      assert_redirected_to admin_customers_url
    end

    test "manager cannot access other tenant customer" do
      other = customers(:other_space_customer)
      sign_in @manager
      get admin_customer_url(other)
      assert_response :not_found
    end
  end
end
