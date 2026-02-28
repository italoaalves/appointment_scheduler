# frozen_string_literal: true

require "test_helper"

module Spaces
  class AppointmentsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager = users(:manager)
      @space   = spaces(:one)
      sign_in @manager
    end

    def pending_appointment
      @space.appointments.create!(
        customer: customers(:one),
        scheduled_at: 3.days.from_now,
        status: :pending,
        duration_minutes: 30
      )
    end

    def confirmed_appointment
      @space.appointments.create!(
        customer: customers(:one),
        scheduled_at: 3.days.ago,
        status: :confirmed,
        duration_minutes: 30
      )
    end

    # ── confirm ───────────────────────────────────────────────────────────────

    test "confirm via turbo_stream marks appointment confirmed" do
      appt = pending_appointment
      patch confirm_appointment_path(appt), params: { source: "index" }, as: :turbo_stream
      assert appt.reload.confirmed?
    end

    test "confirm via turbo_stream returns turbo stream response" do
      appt = pending_appointment
      patch confirm_appointment_path(appt), params: { source: "index" }, as: :turbo_stream
      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
    end

    test "confirm via turbo_stream replaces appointment row" do
      appt = pending_appointment
      patch confirm_appointment_path(appt), params: { source: "index" }, as: :turbo_stream
      assert_includes response.body, dom_id(appt)
    end

    test "confirm via turbo_stream includes pending badge update" do
      appt = pending_appointment
      patch confirm_appointment_path(appt), params: { source: "index" }, as: :turbo_stream
      assert_includes response.body, "pending_appointments_badge"
    end

    test "confirm via turbo_stream includes flash notice" do
      appt = pending_appointment
      patch confirm_appointment_path(appt), params: { source: "index" }, as: :turbo_stream
      assert_includes response.body, "flash_messages"
    end

    test "confirm via html still redirects" do
      appt = pending_appointment
      patch confirm_appointment_path(appt), params: { source: "index" }
      assert_response :redirect
    end

    # ── cancel ────────────────────────────────────────────────────────────────

    test "cancel via turbo_stream marks appointment cancelled" do
      appt = pending_appointment
      patch cancel_appointment_path(appt), params: { source: "index" }, as: :turbo_stream
      assert appt.reload.cancelled?
    end

    test "cancel via turbo_stream on pending filter removes row from DOM" do
      appt = pending_appointment
      patch cancel_appointment_path(appt), params: { source: "index", status: "pending" }, as: :turbo_stream
      assert_includes response.body, "remove"
      assert_includes response.body, dom_id(appt)
    end

    test "cancel via turbo_stream without filter replaces row" do
      appt = pending_appointment
      patch cancel_appointment_path(appt), params: { source: "index" }, as: :turbo_stream
      assert_includes response.body, "replace"
      assert_includes response.body, dom_id(appt)
    end

    # ── no_show ───────────────────────────────────────────────────────────────

    test "no_show via turbo_stream replaces appointment row" do
      appt = confirmed_appointment
      patch no_show_appointment_path(appt), params: { source: "index" }, as: :turbo_stream
      assert_includes response.body, dom_id(appt)
      assert appt.reload.no_show?
    end

    # ── error handling ────────────────────────────────────────────────────────

    test "turbo_stream error response includes alert flash" do
      # Cancel an already-cancelled appointment — invalid transition
      appt = appointments(:one)
      appt.update!(status: :cancelled)
      patch cancel_appointment_path(appt), params: { source: "index" }, as: :turbo_stream
      assert_response :success
      assert_includes response.body, "flash_messages"
      assert_includes response.body, "bg-red-50"
    end
  end
end
