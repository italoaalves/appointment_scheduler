# frozen_string_literal: true

require "test_helper"

class SpaceTest < ActiveSupport::TestCase
  test "has many users" do
    space = spaces(:one)
    assert_includes space.users, users(:manager)
    assert_includes space.users, users(:secretary)
  end

  test "has many customers" do
    space = spaces(:one)
    assert_includes space.customers, customers(:one)
    assert_includes space.customers, customers(:two)
  end

  test "has many appointments" do
    space = spaces(:one)
    assert space.appointments.any?
    assert space.appointments.include?(appointments(:one))
  end

  test "onboarding fields have correct defaults" do
    space = Space.new
    assert_equal 0, space.onboarding_step
    assert_nil space.completed_onboarding_at
    assert_nil space.onboarding_nudge_sent_at
  end

  test "onboarding_complete? returns true when completed_onboarding_at is set" do
    space = spaces(:one)
    assert_not space.onboarding_complete?

    space.update!(completed_onboarding_at: Time.current)
    assert space.onboarding_complete?
  end
end
