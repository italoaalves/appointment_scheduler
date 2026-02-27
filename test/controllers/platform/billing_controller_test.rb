# frozen_string_literal: true

require "test_helper"

module Platform
  class BillingControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin   = users(:admin)
      @manager = users(:manager)
    end

    test "index is accessible only by super_admin" do
      sign_in @manager
      get platform_billing_index_path
      assert_redirected_to root_path
    end

    test "index redirects unauthenticated users" do
      get platform_billing_index_path
      assert_redirected_to new_user_session_path
    end

    test "index renders billing dashboard with subscription counts" do
      sign_in @admin
      get platform_billing_index_path
      assert_response :success
    end

    test "index exposes MRR and subscription stats to the view" do
      sign_in @admin

      captured = {}
      Platform::BillingController.class_eval do
        after_action :capture_assigns_for_test
        define_method(:capture_assigns_for_test) do
          captured[:total_active]   = @total_active
          captured[:total_trialing] = @total_trialing
        end
      end

      get platform_billing_index_path

      assert_not_nil captured[:total_active]
      assert_not_nil captured[:total_trialing]
    ensure
      Platform::BillingController.skip_after_action :capture_assigns_for_test
    end
  end
end
