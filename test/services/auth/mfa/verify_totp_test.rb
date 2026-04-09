# frozen_string_literal: true

require "test_helper"
require "rotp"

module Auth
  module Mfa
    class VerifyTotpTest < ActiveSupport::TestCase
      test "accepts a valid totp code and rejects replay in the same timestep" do
        user = users(:admin)
        user.update!(
          totp_secret: ROTP::Base32.random,
          totp_enabled_at: Time.current,
          mfa_enabled_at: Time.current
        )

        code = ROTP::TOTP.new(user.totp_secret, issuer: "Anella").now

        result = VerifyTotp.call(user: user, code: code)
        assert result.success?
        assert_not_nil user.reload.totp_consumed_timestep

        replay = VerifyTotp.call(user: user, code: code)
        assert_not replay.success?
        assert_equal :replayed_code, replay.error
      end
    end
  end
end
