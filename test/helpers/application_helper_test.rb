# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # Stub Devise helpers that the helper method depends on
  attr_writer :signed_in, :stub_current_user

  def user_signed_in?
    @signed_in
  end

  def current_user
    @stub_current_user
  end

  setup do
    @signed_in         = false
    @stub_current_user = nil
    Notification.delete_all
  end

  test "unread_notifications_count returns 0 when not signed in" do
    assert_equal 0, unread_notifications_count
  end

  test "unread_notifications_count returns correct count for current user" do
    user = users(:manager)
    2.times do |i|
      Notification.create!(
        user: user, notifiable: appointments(:one),
        event_type: "appointment_booked", title: "T#{i}", body: "B#{i}", read: false
      )
    end

    self.signed_in        = true
    self.stub_current_user = user

    assert_equal 2, unread_notifications_count
  end

  test "unread_notifications_count excludes read notifications" do
    user = users(:manager)
    Notification.create!(
      user: user, notifiable: appointments(:one),
      event_type: "appointment_booked", title: "T", body: "B", read: true
    )

    self.signed_in        = true
    self.stub_current_user = user

    assert_equal 0, unread_notifications_count
  end

  test "unread_notifications_count does not count other users notifications" do
    other = users(:admin)
    Notification.create!(
      user: other, notifiable: appointments(:one),
      event_type: "appointment_booked", title: "T", body: "B", read: false
    )

    user = users(:manager)
    self.signed_in        = true
    self.stub_current_user = user

    assert_equal 0, unread_notifications_count
  end

  test "unread_notifications_count is memoized within a request" do
    user = users(:manager)
    self.signed_in        = true
    self.stub_current_user = user

    first_call = unread_notifications_count

    Notification.create!(
      user: user, notifiable: appointments(:one),
      event_type: "appointment_booked", title: "T", body: "B", read: false
    )

    assert_equal first_call, unread_notifications_count
  end
end
