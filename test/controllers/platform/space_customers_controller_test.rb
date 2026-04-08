# frozen_string_literal: true

require "test_helper"

module Platform
  class SpaceCustomersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
    end

    test "show writes an audit log for platform customer access" do
      sign_in @admin

      assert_difference "AuditLog.count", 1 do
        get platform_space_customer_url(spaces(:one), customers(:one))
      end

      assert_response :success
      log = AuditLog.order(:id).last
      assert_equal "privacy.customer_viewed", log.event_type
      assert_equal @admin, log.actor
      assert_equal customers(:one).id, log.subject_id
    end
  end
end
