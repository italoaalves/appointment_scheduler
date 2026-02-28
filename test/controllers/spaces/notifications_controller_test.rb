# frozen_string_literal: true

require "test_helper"

module Spaces
  class NotificationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user  = users(:manager)
      @other = users(:admin)
      sign_in @user
    end

    # ── helpers ───────────────────────────────────────────────────────────────

    def turbo_frame_get(path, frame_id: "notifications_dropdown")
      get path, headers: { "Turbo-Frame" => frame_id }
    end

    # ── index ─────────────────────────────────────────────────────────────────

    test "index returns 200 for turbo frame requests" do
      turbo_frame_get notifications_path
      assert_response :success
    end

    test "index redirects to root for non-turbo-frame requests" do
      get notifications_path
      assert_redirected_to root_path
    end

    test "index only returns current user notifications" do
      other_notif = Notification.create!(
        user: @other, notifiable: appointments(:one),
        event_type: "appointment_booked", title: "Other", body: "Other"
      )

      turbo_frame_get notifications_path
      assert_response :success
      assert_not_includes response.body, other_notif.title
    end

    test "index limits to 10 notifications" do
      11.times do |i|
        Notification.create!(
          user: @user, notifiable: appointments(:one),
          event_type: "appointment_booked", title: "N#{i}", body: "B#{i}"
        )
      end

      turbo_frame_get notifications_path
      assert_response :success
      # 10 shown, 11th not rendered
      assert_not_includes response.body, "N0"
    end

    test "index redirects unauthenticated users" do
      sign_out @user
      turbo_frame_get notifications_path
      assert_redirected_to new_user_session_path
    end

    # ── mark_as_read ──────────────────────────────────────────────────────────

    test "mark_as_read marks notification as read" do
      notif = notifications(:booking_received)
      notif.update!(user: @user)
      assert_not notif.read?

      patch mark_as_read_notification_path(notif)

      assert notif.reload.read?
    end

    test "mark_as_read redirects to appointment for appointment notifiable" do
      notif = notifications(:booking_received)
      notif.update!(user: @user)

      patch mark_as_read_notification_path(notif)

      assert_redirected_to appointment_path(notif.notifiable_id)
    end

    test "mark_as_read redirects to billing for subscription notifiable" do
      notif = notifications(:booking_received)
      notif.update!(user: @user, notifiable: subscriptions(:one))

      patch mark_as_read_notification_path(notif)

      assert_redirected_to settings_billing_path
    end

    test "mark_as_read returns 404 for another user notification" do
      other_notif = Notification.create!(
        user: @other, notifiable: appointments(:one),
        event_type: "appointment_booked", title: "T", body: "B"
      )

      patch mark_as_read_notification_path(other_notif)
      assert_response :not_found
    end

    test "mark_as_read redirects unauthenticated users" do
      sign_out @user
      notif = notifications(:booking_received)
      patch mark_as_read_notification_path(notif)
      assert_redirected_to new_user_session_path
    end

    # ── dismiss ───────────────────────────────────────────────────────────────

    test "dismiss destroys notification" do
      notif = notifications(:booking_received)
      notif.update!(user: @user)

      assert_difference "Notification.count", -1 do
        patch dismiss_notification_path(notif), as: :turbo_stream
      end
    end

    test "dismiss responds with turbo stream" do
      notif = notifications(:booking_received)
      notif.update!(user: @user)

      patch dismiss_notification_path(notif), as: :turbo_stream

      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
    end

    test "dismiss turbo stream includes badge update" do
      notif = notifications(:booking_received)
      notif.update!(user: @user)

      patch dismiss_notification_path(notif), as: :turbo_stream

      assert_includes response.body, "notification_badge"
    end

    test "dismiss returns 404 for another user notification" do
      other_notif = Notification.create!(
        user: @other, notifiable: appointments(:one),
        event_type: "appointment_booked", title: "T", body: "B"
      )

      patch dismiss_notification_path(other_notif), as: :turbo_stream
      assert_response :not_found
    end

    test "dismiss redirects unauthenticated users" do
      sign_out @user
      notif = notifications(:booking_received)
      patch dismiss_notification_path(notif)
      assert_redirected_to new_user_session_path
    end

    # ── mark_all_as_read ──────────────────────────────────────────────────────

    test "mark_all_as_read marks all unread notifications for current user" do
      n1 = Notification.create!(user: @user, notifiable: appointments(:one),
             event_type: "appointment_booked", title: "T1", body: "B1", read: false)
      n2 = Notification.create!(user: @user, notifiable: appointments(:one),
             event_type: "appointment_booked", title: "T2", body: "B2", read: false)

      patch mark_all_as_read_notifications_path

      assert n1.reload.read?
      assert n2.reload.read?
    end

    test "mark_all_as_read does not touch other users notifications" do
      other_notif = Notification.create!(
        user: @other, notifiable: appointments(:one),
        event_type: "appointment_booked", title: "T", body: "B", read: false
      )

      patch mark_all_as_read_notifications_path

      assert_not other_notif.reload.read?
    end

    test "mark_all_as_read responds with turbo stream" do
      patch mark_all_as_read_notifications_path, as: :turbo_stream

      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
    end

    test "mark_all_as_read turbo stream includes badge update" do
      patch mark_all_as_read_notifications_path, as: :turbo_stream

      assert_includes response.body, "notification_badge"
    end

    test "mark_all_as_read falls back to redirect for html" do
      patch mark_all_as_read_notifications_path
      assert_response :redirect
    end

    test "mark_all_as_read redirects unauthenticated users" do
      sign_out @user
      patch mark_all_as_read_notifications_path
      assert_redirected_to new_user_session_path
    end
  end
end
