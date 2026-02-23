# frozen_string_literal: true

require "test_helper"

class SpaceTest < ActiveSupport::TestCase
  test "has many users" do
    space = spaces(:one)
    assert_includes space.users, users(:manager)
    assert_includes space.users, users(:secretary)
  end

  test "has many clients" do
    space = spaces(:one)
    assert_includes space.clients, clients(:one)
    assert_includes space.clients, clients(:two)
  end

  test "has many appointments" do
    space = spaces(:one)
    assert space.appointments.any?
    assert space.appointments.include?(appointments(:one))
  end
end
