# frozen_string_literal: true

require "test_helper"

class SpaceTest < ActiveSupport::TestCase
  test "new spaces default appointment automation configuration" do
    space = Space.new(name: "Automation Clinic", slot_duration_minutes: 30, timezone: "America/Sao_Paulo")

    assert_equal false, space.appointment_automation_enabled
    assert_equal [ 24, 2 ], space.confirmation_lead_hours
    assert_nil space.confirmation_quiet_hours_start
    assert_nil space.confirmation_quiet_hours_end
  end

  test "confirmation lead hours must be present and stay within supported bounds" do
    space = spaces(:one)

    space.confirmation_lead_hours = []
    assert_not space.valid?
    assert_includes space.errors[:confirmation_lead_hours], I18n.t("errors.messages.blank")

    space.confirmation_lead_hours = [ 0, 24 ]
    assert_not space.valid?
    assert_includes space.errors[:confirmation_lead_hours], I18n.t("automation.errors.lead_hours_range")

    space.confirmation_lead_hours = [ 1, 24, 168 ]
    assert space.valid?
  end

  test "appointment automation is active only when enabled and a whatsapp number is connected" do
    space = spaces(:one)

    space.appointment_automation_enabled = false
    assert_not space.appointment_automation_active?

    space.appointment_automation_enabled = true
    assert space.appointment_automation_active?

    space.whatsapp_phone_number.destroy!
    assert_not space.reload.appointment_automation_active?
  end

  test "within_quiet_hours? returns false when quiet hours are not configured" do
    space = spaces(:one)
    space.confirmation_quiet_hours_start = nil
    space.confirmation_quiet_hours_end = nil

    assert_not space.within_quiet_hours?(Time.find_zone(space.timezone).parse("2026-04-17 12:00"))
  end

  test "within_quiet_hours? handles same day windows" do
    space = spaces(:one)
    zone = Time.find_zone(space.timezone)
    space.confirmation_quiet_hours_start = "09:00"
    space.confirmation_quiet_hours_end = "17:00"

    assert space.within_quiet_hours?(zone.parse("2026-04-17 09:00"))
    assert space.within_quiet_hours?(zone.parse("2026-04-17 13:30"))
    assert space.within_quiet_hours?(zone.parse("2026-04-17 17:00"))
    assert_not space.within_quiet_hours?(zone.parse("2026-04-17 08:59"))
    assert_not space.within_quiet_hours?(zone.parse("2026-04-17 17:01"))
  end

  test "within_quiet_hours? handles wraparound windows" do
    space = spaces(:one)
    zone = Time.find_zone(space.timezone)
    space.confirmation_quiet_hours_start = "22:00"
    space.confirmation_quiet_hours_end = "07:00"

    assert space.within_quiet_hours?(zone.parse("2026-04-17 22:00"))
    assert space.within_quiet_hours?(zone.parse("2026-04-17 23:59"))
    assert space.within_quiet_hours?(zone.parse("2026-04-18 06:30"))
    assert space.within_quiet_hours?(zone.parse("2026-04-18 07:00"))
    assert_not space.within_quiet_hours?(zone.parse("2026-04-17 21:59"))
    assert_not space.within_quiet_hours?(zone.parse("2026-04-18 07:01"))
  end

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
