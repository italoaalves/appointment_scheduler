# frozen_string_literal: true

require "test_helper"

module AccountDeletionRequests
  class CancelerTest < ActiveSupport::TestCase
    setup do
      @user = users(:manager_two)
    end

    test "cancels the pending deletion request" do
      request = @user.account_deletion_requests.create!(
        status: :pending,
        requested_at: Time.current,
        scheduled_for: 7.days.from_now
      )

      freeze_time do
        result = Canceler.call(user: @user)

        assert result.success?
        assert_equal request, result.request
        assert_equal "canceled", request.reload.status
        assert_equal Time.current, request.canceled_at
      end
    end

    test "returns failure when there is no active request" do
      result = Canceler.call(user: @user)

      assert_not result.success?
      assert_nil result.request
    end
  end
end
