# frozen_string_literal: true

require "test_helper"

module Auth
  class RecoveryCodesDisplaySessionTest < ActiveSupport::TestCase
    test "stores and returns recovery codes for the same user" do
      session = {}
      user = users(:manager_two)

      RecoveryCodesDisplaySession.store(session:, user:, codes: %w[AAAAA-BBBBB CCCCC-DDDDD])

      assert_equal %w[AAAAA-BBBBB CCCCC-DDDDD], RecoveryCodesDisplaySession.codes(session:, user:)
    end

    test "clears codes when another user attempts to read them" do
      session = {}
      RecoveryCodesDisplaySession.store(session:, user: users(:manager_two), codes: [ "AAAAA-BBBBB" ])

      assert_nil RecoveryCodesDisplaySession.codes(session:, user: users(:secretary))
      assert_nil session[RecoveryCodesDisplaySession::KEY]
    end
  end
end
