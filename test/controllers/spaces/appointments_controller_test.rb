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

    # ── index — today-centered default ────────────────────────────────────────

    test "index defaults to showing today and future appointments only" do
      past_appt = @space.appointments.create!(
        customer: customers(:one), scheduled_at: 2.days.ago, status: :pending, duration_minutes: 30
      )
      future_appt = @space.appointments.create!(
        customer: customers(:one), scheduled_at: 2.days.from_now, status: :pending, duration_minutes: 30
      )

      get appointments_path
      assert_response :success
      assert_includes response.body, dom_id(future_appt)
      assert_not_includes response.body, dom_id(past_appt)
    end

    test "index with explicit date_from shows past appointments" do
      past_appt = @space.appointments.create!(
        customer: customers(:one), scheduled_at: 5.days.ago, status: :finished, duration_minutes: 30
      )

      get appointments_path, params: { date_from: 7.days.ago.to_date.iso8601 }
      assert_response :success
      assert_includes response.body, dom_id(past_appt)
    end

    # ── before_date (past continuity loader) ──────────────────────────────────

    test "before_date returns turbo_stream with past appointments prepended" do
      past_appt = @space.appointments.create!(
        customer: customers(:one), scheduled_at: 3.days.ago, status: :finished, duration_minutes: 30
      )

      get appointments_path,
          params: { before_date: Date.current.iso8601 },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_includes response.body, dom_id(past_appt)
      assert_includes response.body, "appointments-feed-list"
    end

    test "before_date replaces past-loader-trigger when more pages exist" do
      # 21 past appointments — exceeds page size of 20
      21.times do |i|
        @space.appointments.create!(
          customer: customers(:one), scheduled_at: (i + 1).days.ago, status: :finished, duration_minutes: 30
        )
      end

      get appointments_path,
          params: { before_date: Date.current.iso8601 },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
      assert_response :success
      assert_includes response.body, "past-loader-trigger"
      assert_includes response.body, 'action="replace"'
    end

    test "before_date removes past-loader-trigger when no more pages" do
      @space.appointments.create!(
        customer: customers(:one), scheduled_at: 3.days.ago, status: :finished, duration_minutes: 30
      )

      get appointments_path,
          params: { before_date: Date.current.iso8601 },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
      assert_response :success
      assert_includes response.body, "past-loader-trigger"
      assert_includes response.body, 'action="remove"'
    end

    test "before_date respects status filter" do
      finished = @space.appointments.create!(
        customer: customers(:one), scheduled_at: 2.days.ago, status: :finished, duration_minutes: 30
      )
      pending = @space.appointments.create!(
        customer: customers(:one), scheduled_at: 3.days.ago, status: :pending, duration_minutes: 30
      )

      get appointments_path,
          params: { before_date: Date.current.iso8601, status: "finished" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
      assert_includes response.body, dom_id(finished)
      assert_not_includes response.body, dom_id(pending)
    end

    test "before_date with HTML request redirects to appointments_path" do
      get appointments_path, params: { before_date: Date.current.iso8601 }
      assert_redirected_to appointments_path
    end

    test "before_date with invalid date returns bad_request" do
      get appointments_path,
          params: { before_date: "not-a-date" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
      assert_response :bad_request
    end
  end
end
