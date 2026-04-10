# frozen_string_literal: true

require "test_helper"

module Auth
  module Mfa
    class VerifyRecoveryCodeTest < ActiveSupport::TestCase
      test "recovery code is single use" do
        user = users(:admin)
        codes = GenerateRecoveryCodes.call(user: user)

        first_attempt = VerifyRecoveryCode.call(user: user, code: codes.first)
        assert first_attempt.success?

        second_attempt = VerifyRecoveryCode.call(user: user, code: codes.first)
        assert_not second_attempt.success?
        assert_equal :invalid_code, second_attempt.error
      end
    end
  end
end
