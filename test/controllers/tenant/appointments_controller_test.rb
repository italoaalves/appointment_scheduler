# frozen_string_literal: true

require "test_helper"

module Tenant
  class AppointmentsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager = users(:manager)
      @secretary = users(:secretary)
      @admin = users(:admin)
      @appointment = appointments(:one)
      @space = spaces(:one)
    end

    test "redirects unauthenticated to login" do
      get appointments_url
      assert_redirected_to new_user_session_url
    end

    test "redirects admin to platform" do
      sign_in @admin
      get appointments_url
      assert_redirected_to platform_root_url
    end

    test "manager can get index" do
      sign_in @manager
      get appointments_url
      assert_response :success
    end

    test "secretary can get index" do
      sign_in @secretary
      get appointments_url
      assert_response :success
    end

    test "manager can get pending" do
      sign_in @manager
      get pending_appointments_url
      assert_response :success
    end

    test "manager can show appointment" do
      sign_in @manager
      get appointment_url(@appointment)
      assert_response :success
    end

    test "manager can confirm appointment" do
      pending_apt = @space.appointments.create!(
        customer: customers(:one),
        scheduled_at: 3.days.from_now,
        status: :pending,
        duration_minutes: 30
      )
      sign_in @manager
      patch confirm_appointment_url(pending_apt)
      assert pending_apt.reload.confirmed?
    end

    test "manager can cancel appointment" do
      sign_in @manager
      patch cancel_appointment_url(@appointment)
      assert @appointment.reload.cancelled?
    end

    test "manager cannot access other tenant appointment" do
      other_space = spaces(:two)
      other_apt = other_space.appointments.create!(
        customer: customers(:other_space_customer),
        scheduled_at: 3.days.from_now,
        status: :pending,
        duration_minutes: 30
      )
      sign_in @manager
      get appointment_url(other_apt)
      assert_response :not_found
    end

    test "secretary without destroy_appointments cannot destroy" do
      sign_in @secretary
      delete appointment_url(@appointment)
      assert_redirected_to appointments_url
      assert Appointment.exists?(@appointment.id)
    end
  end
end
