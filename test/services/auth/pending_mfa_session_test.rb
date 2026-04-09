# frozen_string_literal: true

require "test_helper"

module Auth
  class PendingMfaSessionTest < ActiveSupport::TestCase
    test "stores and returns pending mfa state" do
      session = {}
      user = users(:admin)

      PendingMfaSession.start(
        session: session,
        user: user,
        primary_method: :password,
        remember_me: true,
        return_to: "/platform"
      )

      pending = PendingMfaSession.fetch(session: session)

      assert_equal user.id, pending[:user_id]
      assert_equal "password", pending[:primary_method]
      assert_equal true, pending[:remember_me]
      assert_equal "/platform", pending[:return_to]
      assert_equal 0, pending[:attempts]
    end

    test "expires stale pending mfa state" do
      session = {
        "auth.pending_mfa" => {
          "user_id" => users(:admin).id,
          "primary_method" => "password",
          "remember_me" => false,
          "started_at" => 20.minutes.ago.to_i,
          "attempts" => 0
        }
      }

      assert_nil PendingMfaSession.fetch(session: session)
      assert_nil session["auth.pending_mfa"]
    end
  end
end
