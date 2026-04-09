# frozen_string_literal: true

require "test_helper"

module Auth
  class CompleteSocialSignupTest < ActiveSupport::TestCase
    test "creates a confirmed user and linked identity from pending social signup" do
      session = {}
      BeginSocialSignup.call(
        session: session,
        provider: "google_oauth2",
        uid: "google-finish",
        email: "social_finish@example.com",
        email_verified: true,
        name: "Social Finish"
      )

      result = nil

      assert_difference("User.count", 1) do
        assert_difference("UserIdentity.count", 1) do
          result = CompleteSocialSignup.call(
            session: session,
            params: {
              name: "Social Finish",
              phone_number: "+5511999990777",
              accept_terms_of_service: "1",
              accept_privacy_policy: "1"
            }
          )
        end
      end

      assert result.success?
      assert result.user.confirmed?
      assert_equal "social_finish@example.com", result.user.email
      assert_equal "google_oauth2", result.identity.provider
      assert_equal "google-finish", result.identity.uid
      assert_not_nil result.user.space
      assert_nil BeginSocialSignup.fetch(session: session)
    end

    test "keeps the pending signup when required fields are missing" do
      session = {}
      BeginSocialSignup.call(
        session: session,
        provider: "google_oauth2",
        uid: "google-invalid",
        email: "social_invalid@example.com",
        email_verified: true,
        name: "Social Invalid"
      )

      result = nil

      assert_no_difference("User.count") do
        assert_no_difference("UserIdentity.count") do
          result = CompleteSocialSignup.call(
            session: session,
            params: {
              name: "",
              phone_number: "",
              accept_terms_of_service: "0",
              accept_privacy_policy: "0"
            }
          )
        end
      end

      assert_not result.success?
      assert result.user.errors[:phone_number].any?
      assert result.user.errors[:accept_terms_of_service].any?
      assert result.user.errors[:accept_privacy_policy].any?
      assert_equal "social_invalid@example.com", BeginSocialSignup.fetch(session: session)[:email]
    end
  end
end
