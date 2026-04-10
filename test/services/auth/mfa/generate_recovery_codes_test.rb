# frozen_string_literal: true

require "test_helper"

module Auth
  module Mfa
    class GenerateRecoveryCodesTest < ActiveSupport::TestCase
      test "generates and replaces recovery codes" do
        user = users(:admin)

        first_codes = GenerateRecoveryCodes.call(user: user)
        assert_equal 10, first_codes.length
        assert_equal 10, user.user_recovery_codes.count

        second_codes = GenerateRecoveryCodes.call(user: user)
        assert_equal 10, second_codes.length
        assert_equal 10, user.user_recovery_codes.count
        assert_not_equal first_codes.sort, second_codes.sort
      end
    end
  end
end
