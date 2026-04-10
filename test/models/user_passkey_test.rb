# frozen_string_literal: true

require "test_helper"

class UserPasskeyTest < ActiveSupport::TestCase
  test "requires identifying fields" do
    passkey = UserPasskey.new(user: users(:admin))

    assert_not passkey.valid?
    assert passkey.errors.added?(:external_id, :blank)
    assert passkey.errors.added?(:public_key, :blank)
    assert passkey.errors.added?(:label, :blank)
  end
end
