# frozen_string_literal: true

require "test_helper"

module Auth
  class PrimaryAuthenticationTest < ActiveSupport::TestCase
    test "authenticates a confirmed user with valid credentials" do
      result = PrimaryAuthentication.call(
        email: users(:manager).email,
        password: "password123"
      )

      assert result.success?
      assert_equal users(:manager), result.user
      assert_nil result.error
    end

    test "rejects invalid credentials" do
      result = PrimaryAuthentication.call(
        email: users(:manager).email,
        password: "wrong-password"
      )

      assert_not result.success?
      assert_nil result.user
      assert_equal :invalid, result.error
    end

    test "rejects inactive users after password verification" do
      user = users(:manager)
      user.update!(confirmed_at: nil)

      result = PrimaryAuthentication.call(
        email: user.email,
        password: "password123"
      )

      assert_not result.success?
      assert_equal user, result.user
      assert_equal :unconfirmed, result.error
    end
  end
end
