# frozen_string_literal: true

require "test_helper"

class PasskeyMfaTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
  end

  test "super admin can register a passkey during required mfa setup" do
    post user_session_path, params: {
      user: {
        email: @admin.email,
        password: "password123"
      }
    }

    assert_redirected_to new_user_mfa_totp_enrollment_path

    post registration_options_user_mfa_passkeys_path
    assert_response :success

    options = JSON.parse(response.body)
    credential = webauthn_fake_client.create(
      challenge: options.fetch("challenge"),
      rp_id: WebAuthn.configuration.rp_id,
      user_verified: true
    )

    post user_mfa_passkeys_path, params: {
      label: "MacBook Pro",
      public_key_credential: credential
    }, as: :json

    assert_response :success
    assert_equal user_mfa_recovery_codes_path, JSON.parse(response.body).fetch("redirect_url")

    get user_mfa_recovery_codes_path
    assert_response :success
    assert_select "input[type=submit][value=?]", I18n.t("mfa.recovery_codes.submit")

    post user_mfa_recovery_codes_path
    assert_redirected_to platform_root_path
  end

  test "super admin with a passkey can complete the mfa challenge" do
    fake_client = webauthn_fake_client
    register_passkey_for(@admin, fake_client:)

    post user_session_path, params: {
      user: {
        email: @admin.email,
        password: "password123"
      }
    }

    assert_redirected_to user_mfa_challenge_path
    follow_redirect!
    assert_response :success
    assert_select "[data-passkey-action='authenticate']"

    post authentication_options_user_mfa_passkeys_path
    assert_response :success

    options = JSON.parse(response.body)
    credential = fake_client.get(
      challenge: options.fetch("challenge"),
      rp_id: WebAuthn.configuration.rp_id,
      user_verified: true,
      allow_credentials: @admin.user_passkeys.pluck(:external_id)
    )

    post authenticate_user_mfa_passkeys_path, params: {
      public_key_credential: credential
    }, as: :json

    assert_response :success
    assert_equal platform_root_path, JSON.parse(response.body).fetch("redirect_url")
  end

  private

  def register_passkey_for(user, fake_client: webauthn_fake_client)
    session_hash = {}
    options = Auth::Mfa::Webauthn::GenerateRegistrationOptions.call(user:, session: session_hash)
    credential = fake_client.create(
      challenge: options.challenge,
      rp_id: WebAuthn.configuration.rp_id,
      user_verified: true
    )

    result = Auth::Mfa::Webauthn::RegisterPasskey.call(
      user:,
      session: session_hash,
      credential:,
      label: "Primary passkey"
    )
    assert result.success?

    user.update!(mfa_enabled_at: Time.current)
  end
end
