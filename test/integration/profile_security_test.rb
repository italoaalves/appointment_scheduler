# frozen_string_literal: true

require "test_helper"

class ProfileSecurityTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:manager_two)
  end

  test "signed in user can register a first passkey from profile security" do
    sign_in @user

    get profile_security_path
    assert_response :success
    assert_select "h1", text: I18n.t("profiles.security.title")

    post registration_options_profile_security_passkeys_path
    assert_response :success

    options = JSON.parse(response.body)
    credential = webauthn_fake_client.create(
      challenge: options.fetch("challenge"),
      rp_id: WebAuthn.configuration.rp_id,
      user_verified: true
    )

    post profile_security_passkeys_path, params: {
      label: "MacBook Pro",
      public_key_credential: credential
    }, as: :json

    assert_response :success
    assert_equal profile_security_recovery_codes_path, JSON.parse(response.body).fetch("redirect_url")

    get profile_security_recovery_codes_path
    assert_response :success
    post acknowledge_profile_security_recovery_codes_path

    assert_redirected_to profile_security_path
    assert @user.reload.mfa_enabled?
    assert_equal 1, @user.user_passkeys.count
  end

  test "security page shows account settings shell and linked identities" do
    @user.user_identities.create!(
      provider: "google_oauth2",
      uid: "google-profile-security",
      email: @user.email,
      email_verified: true,
      last_authenticated_at: Time.current
    )
    sign_in @user

    get profile_security_path

    assert_response :success
    assert_select "[data-role='settings-shell']"
    assert_select "a[href='#{edit_profile_path}']", text: I18n.t("account.sidebar.profile"), minimum: 1
    assert_select "a[href='#{edit_preferences_path}']", text: I18n.t("account.sidebar.preferences"), minimum: 1
    assert_select "a[href='#{profile_security_path}']", text: I18n.t("account.sidebar.security"), minimum: 1
    assert_select "p", text: "Google"
    assert_select "span", text: I18n.t("profiles.security.identities.linked"), minimum: 1
    assert_select "form[action='#{user_apple_omniauth_authorize_path}'][method='post']"
    assert_select "input[name='origin'][value='#{profile_security_path}']"
  end

  test "signed in user can enable totp from profile security" do
    sign_in @user

    get new_profile_security_totp_enrollment_path
    assert_response :success

    secret = css_select("p.font-mono").first.text.strip
    code = ROTP::TOTP.new(secret, issuer: AppBrand.authenticator_name).now

    post profile_security_totp_enrollment_path, params: { code: code }

    assert_redirected_to profile_security_recovery_codes_path
    follow_redirect!
    assert_response :success

    post acknowledge_profile_security_recovery_codes_path

    assert_redirected_to profile_security_path
    assert @user.reload.totp_enabled?
    assert @user.mfa_enabled?
  end

  test "signed in user can regenerate recovery codes" do
    @user.update!(
      mfa_enabled_at: Time.current,
      totp_secret: ROTP::Base32.random,
      totp_enabled_at: Time.current
    )
    Auth::Mfa::GenerateRecoveryCodes.call(user: @user)
    original_digests = @user.user_recovery_codes.pluck(:code_digest).sort
    sign_in @user

    post regenerate_profile_security_recovery_codes_path

    assert_redirected_to profile_security_recovery_codes_path
    follow_redirect!
    assert_response :success
    assert_not_equal original_digests, @user.reload.user_recovery_codes.pluck(:code_digest).sort
  end
end
