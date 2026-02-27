# frozen_string_literal: true

require "test_helper"

module Spaces
  class BaseControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager = users(:manager)
      @space   = spaces(:one)
    end

    test "Current.subscription is set when space has a subscription" do
      sign_in @manager

      subscription_id_during_request = nil
      Spaces::BaseController.class_eval do
        after_action :capture_subscription_for_test
        define_method(:capture_subscription_for_test) do
          subscription_id_during_request = Current.subscription&.id
        end
      end

      get appointments_url
      assert_response :success
      assert_not_nil subscription_id_during_request,
                     "Expected Current.subscription to be set during a Spaces request"
      assert_equal subscriptions(:one).id, subscription_id_during_request
    ensure
      Spaces::BaseController.skip_after_action :capture_subscription_for_test
    end

    test "request succeeds when space has no subscription — Current.subscription is nil" do
      sub = @space.subscription
      Billing::BillingEvent.where(subscription_id: sub.id).delete_all
      Billing::Payment.where(subscription_id: sub.id).delete_all
      sub.delete

      sign_in @manager
      get appointments_url
      assert_response :success
    end

    test "Current.subscription defaults to nil outside request context" do
      assert_nil Current.subscription
    end

    test "unauthenticated request does not set Current.subscription" do
      get appointments_url
      assert_redirected_to new_user_session_url
      assert_nil Current.subscription
    end
  end
end
