# frozen_string_literal: true

require "test_helper"

class DashboardOverviewServiceTest < ActiveSupport::TestCase
  setup do
    @space = spaces(:one)
    @user = users(:manager)
    @timezone = "America/Sao_Paulo"

    # Mock TimezoneResolver if necessary or ensure space has a timezone
    # In Minitest we can use stub if needed, but usually fixtures are better
  end

  test "returns a hash with all required keys" do
    result = DashboardOverviewService.call(space: @space)

    assert_includes result.keys, :calendar_today
    assert_includes result.keys, :calendar_week
    assert_includes result.keys, :calendar_month
    assert_includes result.keys, :stats_today
    assert_includes result.keys, :stats_week
    assert_includes result.keys, :stats_month
    assert_includes result.keys, :calendar_space
    assert_includes result.keys, :pending_count
    assert_includes result.keys, :today_summary
    assert_includes result.keys, :upcoming
    assert_includes result.keys, :attention
    assert_includes result.keys, :this_week
    assert_includes result.keys, :automation
  end

  test "calculates today_summary correctly with data" do
    # Use existing fixtures or create data manually
    appt = appointments(:one)
    appt.update!(scheduled_at: Time.current.beginning_of_day + 10.hours, status: :confirmed)

    result = DashboardOverviewService.call(space: @space)
    summary = result[:today_summary]

    assert_kind_of Integer, summary[:total]
    assert_kind_of Integer, summary[:confirmed]
    assert_kind_of Integer, summary[:pending]
  end

  test "fetches upcoming appointments" do
    result = DashboardOverviewService.call(space: @space)
    assert_kind_of ActiveRecord::Relation, result[:upcoming]
    result[:upcoming].each do |appt|
      assert_equal @space.id, appt.space_id
    end
  end

  test "calculates attention metrics" do
    result = DashboardOverviewService.call(space: @space)
    assert_kind_of Hash, result[:attention]
    assert_kind_of Integer, result[:attention][:pending_confirmations]
    assert_kind_of Integer, result[:attention][:unread_conversations]
  end

  test "calculates this_week metrics" do
    result = DashboardOverviewService.call(space: @space)
    assert_kind_of Hash, result[:this_week]
    assert_kind_of Integer, result[:this_week][:appointments_count]
    assert_kind_of Integer, result[:this_week][:new_customers]
    assert_kind_of Integer, result[:this_week][:minutes_booked]
  end

  test "calculates automation metrics" do
    result = DashboardOverviewService.call(space: @space)
    assert_kind_of Hash, result[:automation]
    assert_kind_of Integer, result[:automation][:automated_conversations]
  end
end
