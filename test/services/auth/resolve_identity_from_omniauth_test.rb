# frozen_string_literal: true

require "test_helper"

module Auth
  class ResolveIdentityFromOmniauthTest < ActiveSupport::TestCase
    test "signs in an already linked identity and refreshes last_authenticated_at" do
      user = users(:manager)
      identity = UserIdentity.create!(
        user: user,
        provider: "google_oauth2",
        uid: "google-linked",
        email: user.email,
        email_verified: true,
        last_authenticated_at: 2.days.ago
      )

      freeze_time do
        result = ResolveIdentityFromOmniauth.call(
          auth: omniauth_hash(
            provider: :google_oauth2,
            uid: "google-linked",
            email: user.email,
            name: user.name
          ),
          session: {}
        )

        assert_equal :sign_in, result.outcome
        assert_equal user, result.user
        assert_not result.linked
        assert_equal Time.current.to_i, identity.reload.last_authenticated_at.to_i
      end
    end

    test "auto links a trusted verified email to an existing user and confirms them" do
      user = users(:secretary)
      user.update_column(:confirmed_at, nil)

      result = ResolveIdentityFromOmniauth.call(
        auth: omniauth_hash(
          provider: :google_oauth2,
          uid: "google-secretary",
          email: user.email,
          name: user.name,
          email_verified: true
        ),
        session: {}
      )

      assert_equal :sign_in, result.outcome
      assert result.linked
      assert_equal user, result.user
      assert user.reload.confirmed?
      assert_equal [ "google_oauth2", "google-secretary" ], user.user_identities.pick(:provider, :uid)
    end

    test "stores a pending signup when no existing account matches" do
      session = {}

      result = ResolveIdentityFromOmniauth.call(
        auth: omniauth_hash(
          provider: :google_oauth2,
          uid: "google-new",
          email: "new_social_user@example.com",
          name: "New Social User"
        ),
        session: session
      )

      assert_equal :pending_signup, result.outcome

      pending_signup = BeginSocialSignup.fetch(session: session)
      assert_equal "google_oauth2", pending_signup[:provider]
      assert_equal "google-new", pending_signup[:uid]
      assert_equal "new_social_user@example.com", pending_signup[:email]
      assert_equal "New Social User", pending_signup[:name]
    end

    test "fails when provider does not return an email for an unlinked account" do
      session = {}

      result = ResolveIdentityFromOmniauth.call(
        auth: omniauth_hash(
          provider: :apple,
          uid: "apple-no-email",
          email: nil,
          name: "Apple User"
        ),
        session: session
      )

      assert_equal :failure, result.outcome
      assert_equal :email_required, result.error
      assert_nil BeginSocialSignup.fetch(session: session)
    end
  end
end
