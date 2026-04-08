# frozen_string_literal: true

require "test_helper"

module AccountDeletionRequests
  class RequesterTest < ActiveSupport::TestCase
    setup do
      @user = users(:manager_two)
    end

    test "creates a pending deletion request with a 7 day grace period" do
      freeze_time do
        result = Requester.call(user: @user)

        assert result.success?
        assert_equal "pending", result.request.status
        assert_equal Time.current, result.request.requested_at
        assert_equal 7.days.from_now, result.request.scheduled_for
      end
    end

    test "returns existing pending request when one is already active" do
      existing = @user.account_deletion_requests.create!(
        status: :pending,
        requested_at: Time.current,
        scheduled_for: 7.days.from_now
      )

      result = Requester.call(user: @user)

      assert_not result.success?
      assert_equal existing, result.request
    end
  end
end
