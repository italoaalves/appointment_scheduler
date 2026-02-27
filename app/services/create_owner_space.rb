# frozen_string_literal: true

class CreateOwnerSpace
  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    return if @user.super_admin?
    return if SpaceMembership.exists?(user_id: @user.id)

    space = Space.new(name: @user.name.presence || @user.email)
    space.owner_id = @user.id
    space.save!
    SpaceMembership.create!(user_id: @user.id, space_id: space.id)
    grant_owner_permissions
    seed_default_availability(space)
    Billing::TrialManager.start_trial(space)
    space
  end

  private

  def grant_owner_permissions
    PermissionService::ALLOWED_PERMISSIONS.each do |perm|
      @user.user_permissions.find_or_create_by!(permission: perm)
    end
    @user.clear_permission_cache!
  end

  def seed_default_availability(space)
    return if space.availability_schedule.present?

    schedule = AvailabilitySchedule.create!(
      schedulable: space,
      timezone: space.timezone.presence || "America/Sao_Paulo"
    )
    Space::DEFAULT_BUSINESS_HOURS.each do |weekday_str, hours|
      open_parts = hours["open"].split(":").map(&:to_i)
      close_parts = hours["close"].split(":").map(&:to_i)
      schedule.availability_windows.create!(
        weekday: weekday_str.to_i,
        opens_at: Time.utc(2000, 1, 1, open_parts[0], open_parts[1] || 0),
        closes_at: Time.utc(2000, 1, 1, close_parts[0], close_parts[1] || 0)
      )
    end
  end
end
