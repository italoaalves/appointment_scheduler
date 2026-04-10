# frozen_string_literal: true

require "test_helper"
require "rotp"

class MfaEnforcementTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
  end

  test "super admin without mfa is redirected to setup from platform pages" do
    sign_in @admin, mfa_verified: false

    get platform_users_path

    assert_redirected_to new_user_mfa_totp_enrollment_path
  end

  test "super admin with mfa enabled but unverified is redirected to challenge" do
    @admin.update!(
      totp_secret: ROTP::Base32.random,
      totp_enabled_at: Time.current,
      mfa_enabled_at: Time.current
    )
    sign_in @admin, mfa_verified: false

    get platform_users_path

    assert_redirected_to user_mfa_challenge_path
  end

  test "mfa-verified super admin can access platform pages" do
    @admin.update!(
      totp_secret: ROTP::Base32.random,
      totp_enabled_at: Time.current,
      mfa_enabled_at: Time.current
    )
    sign_in @admin, mfa_verified: true

    get platform_users_path

    assert_response :success
  end
end
