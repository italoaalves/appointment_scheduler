# frozen_string_literal: true

require "test_helper"

class CreateOwnerSpaceTest < ActiveSupport::TestCase
  test "creates space with default Mon-Fri 9-17 availability on signup" do
    user = User.create!(
      email: "newowner@test.com",
      password: "password123",
      name: "New Owner"
    )

    space = user.reload.space
    assert_not_nil space
    assert_equal "New Owner", space.name
    assert space.availability_configured?
    assert_equal 5, space.availability_schedule.availability_windows.count

    weekdays = space.availability_schedule.availability_windows.pluck(:weekday).sort
    assert_equal [ 1, 2, 3, 4, 5 ], weekdays

    space.availability_schedule.availability_windows.each do |wl|
      assert_equal "09:00", wl.opens_at.strftime("%H:%M")
      assert_equal "17:00", wl.closes_at.strftime("%H:%M")
    end
  end

  test "is idempotent — second call does not create duplicate space" do
    user = User.create!(
      email: "idempotent@test.com",
      password: "password123",
      name: "Idempotent User"
    )

    space = user.reload.space
    assert_not_nil space

    result = CreateOwnerSpace.call(user)
    assert_nil result
    assert_equal 1, SpaceMembership.where(user_id: user.id).count
    assert_equal space, user.reload.space
  end

  test "grants owner all manager permissions on signup" do
    user = User.create!(
      email: "owner_perms@test.com",
      password: "password123",
      name: "Owner Perms"
    )

    user.reload
    assert_not_nil user.space

    PermissionService::ALLOWED_PERMISSIONS.each do |perm|
      assert user.can?(perm.to_sym), "Expected owner to have #{perm}"
    end
  end

  test "skips space creation for super_admin" do
    user = User.create!(
      email: "admin@test.com",
      password: "password123",
      name: "Admin",
      system_role: :super_admin
    )

    result = CreateOwnerSpace.call(user)
    assert_nil result
    assert_equal 0, SpaceMembership.where(user_id: user.id).count
  end
end
