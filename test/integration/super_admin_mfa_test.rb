# frozen_string_literal: true

require "test_helper"
require "rotp"

class SuperAdminMfaTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
  end

  test "regular users still sign in without an mfa challenge" do
    post user_session_path, params: {
      user: {
        email: users(:manager).email,
        password: "password123"
      }
    }

    assert_redirected_to onboarding_wizard_path
  end

  test "super admin without mfa is redirected to totp setup after primary authentication" do
    post user_session_path, params: {
      user: {
        email: @admin.email,
        password: "password123"
      }
    }

    assert_redirected_to new_user_mfa_totp_enrollment_path
    follow_redirect!
    assert_response :success
    assert_select "input[name='code']"
  end

  test "super admin with mfa enabled is redirected to challenge after primary authentication" do
    enable_totp_for(@admin)

    post user_session_path, params: {
      user: {
        email: @admin.email,
        password: "password123"
      }
    }

    assert_redirected_to user_mfa_challenge_path
    follow_redirect!
    assert_response :success
    assert_select "input[name='otp_attempt']"
  end

  test "valid totp challenge completes sign in" do
    enable_totp_for(@admin)

    post user_session_path, params: {
      user: {
        email: @admin.email,
        password: "password123"
      }
    }
    assert_redirected_to user_mfa_challenge_path

    post user_mfa_challenge_path, params: {
      otp_attempt: current_totp_for(@admin)
    }

    assert_redirected_to platform_root_path
    follow_redirect!
    assert_response :success
  end

  test "recovery code can complete sign in once" do
    enable_totp_for(@admin)
    recovery_codes = Auth::Mfa::GenerateRecoveryCodes.call(user: @admin)

    post user_session_path, params: {
      user: {
        email: @admin.email,
        password: "password123"
      }
    }

    post user_mfa_challenge_path, params: {
      recovery_code_attempt: recovery_codes.first
    }
    assert_redirected_to platform_root_path

    delete destroy_user_session_path

    post user_session_path, params: {
      user: {
        email: @admin.email,
        password: "password123"
      }
    }

    post user_mfa_challenge_path, params: {
      recovery_code_attempt: recovery_codes.first
    }

    assert_response :unprocessable_entity
    assert_select "input[name='recovery_code_attempt']"
  end

  private

  def enable_totp_for(user)
    user.update!(
      totp_secret: ROTP::Base32.random,
      totp_enabled_at: Time.current,
      mfa_enabled_at: Time.current
    )
  end

  def current_totp_for(user)
    ROTP::TOTP.new(user.totp_secret, issuer: AppBrand.authenticator_name).now
  end
end
