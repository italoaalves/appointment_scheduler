# frozen_string_literal: true

require "test_helper"

module Auth
  module Mfa
    class EnrollTotpTest < ActiveSupport::TestCase
      test "enables totp and generates recovery codes for the first factor" do
        user = users(:manager_two)
        secret = ROTP::Base32.random
        code = ROTP::TOTP.new(secret, issuer: "Anella").now

        result = EnrollTotp.call(user:, secret:, code:)

        assert result.success?
        assert_equal 10, result.recovery_codes.length
        assert user.reload.totp_enabled?
        assert user.mfa_enabled?
      end

      test "returns an error when the code is invalid" do
        user = users(:manager_two)

        result = EnrollTotp.call(user:, secret: ROTP::Base32.random, code: "000000")

        assert_not result.success?
        assert_equal :invalid_code, result.error
      end

      test "does not replace recovery codes when mfa is already enabled" do
        user = users(:manager_two)
        user.update!(mfa_enabled_at: Time.current)
        Auth::Mfa::GenerateRecoveryCodes.call(user:)
        original_digests = user.user_recovery_codes.pluck(:code_digest).sort
        secret = ROTP::Base32.random
        code = ROTP::TOTP.new(secret, issuer: "Anella").now

        result = EnrollTotp.call(user:, secret:, code:)

        assert result.success?
        assert_nil result.recovery_codes
        assert_equal 10, user.user_recovery_codes.count
        assert_equal original_digests, user.user_recovery_codes.pluck(:code_digest).sort
      end
    end
  end
end
