# frozen_string_literal: true

require "test_helper"

class UserIdentityTest < ActiveSupport::TestCase
  setup do
    @user = users(:manager)
  end

  test "requires provider uid pairs to be unique" do
    UserIdentity.create!(
      user: @user,
      provider: "google_oauth2",
      uid: "google-123",
      email: @user.email,
      email_verified: true
    )

    duplicate = UserIdentity.new(
      user: users(:secretary),
      provider: "google_oauth2",
      uid: "google-123",
      email: "other@example.com",
      email_verified: true
    )

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:uid, :taken, value: "google-123")
  end

  test "allows linking multiple providers to the same user" do
    assert_difference "UserIdentity.count", 2 do
      UserIdentity.create!(
        user: @user,
        provider: "google_oauth2",
        uid: "google-123",
        email: @user.email,
        email_verified: true
      )

      UserIdentity.create!(
        user: @user,
        provider: "apple",
        uid: "apple-123",
        email: @user.email,
        email_verified: true
      )
    end

    assert_equal %w[apple google_oauth2], @user.user_identities.order(:provider).pluck(:provider)
  end
end
