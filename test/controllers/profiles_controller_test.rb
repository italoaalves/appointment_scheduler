# frozen_string_literal: true

require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    # spaces(:one) has a trialing subscription; spaces(:two) has an active subscription.
    @trialing_user = users(:manager)
    @active_user   = users(:manager_two)
    @secretary     = users(:secretary)

    clear_enqueued_jobs
    clear_performed_jobs
  end

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  # --- Phone update blocked during trial ---

  test "trialing user cannot change phone number via profile form" do
    @trialing_user.update_column(:phone_number, "+5511999990100")
    sign_in @trialing_user

    patch profile_path, params: {
      user: { phone_number: "+5511999990101" }
    }

    # Controller strips the field → phone stays unchanged
    assert_equal "+5511999990100", @trialing_user.reload.phone_number
  end

  test "trialing user can still update name during trial" do
    sign_in @trialing_user

    patch profile_path, params: {
      user: { name: "New Name" }
    }

    assert_redirected_to edit_profile_path
    assert_equal "New Name", @trialing_user.reload.name
  end

  # --- Phone update allowed on active plan ---

  test "active subscriber can change phone number via profile form" do
    @active_user.update_column(:phone_number, "+5511999990200")
    sign_in @active_user

    patch profile_path, params: {
      user: { phone_number: "+5511999990201" }
    }

    assert_redirected_to edit_profile_path
    assert_equal "+5511999990201", @active_user.reload.phone_number
  end

  # --- Profile page shows read-only field for trialing users ---

  test "profile edit shows phone field as disabled for trialing user" do
    sign_in @trialing_user
    get edit_profile_path

    assert_response :success
    assert_select "input[name='user[phone_number]'][disabled]"
  end

  test "profile edit shows phone field as enabled for active user" do
    sign_in @active_user
    get edit_profile_path

    assert_response :success
    assert_select "input[name='user[phone_number]']:not([disabled])"
  end

  test "request data export enqueues package delivery job for current user" do
    sign_in @trialing_user

    assert_enqueued_with(job: DataExports::PackageDeliveryJob, args: [ @trialing_user.id ]) do
      post request_data_export_profile_path
    end

    assert_redirected_to edit_profile_path
  end

  test "request data export is available to non-manager users too" do
    sign_in @secretary

    assert_enqueued_with(job: DataExports::PackageDeliveryJob, args: [ @secretary.id ]) do
      post request_data_export_profile_path
    end

    assert_redirected_to edit_profile_path
  end

  test "request deletion creates a pending deletion request with grace period" do
    sign_in @active_user

    freeze_time do
      assert_difference "AccountDeletionRequest.count", 1 do
        post request_deletion_profile_path
      end

      request = @active_user.account_deletion_requests.order(:created_at).last
      assert_redirected_to edit_profile_path
      assert_equal "pending", request.status
      assert_equal Time.current, request.requested_at
      assert_equal 7.days.from_now, request.scheduled_for
    end
  end

  test "request deletion does not create a duplicate pending request" do
    @active_user.account_deletion_requests.create!(
      status: :pending,
      requested_at: Time.current,
      scheduled_for: 7.days.from_now
    )
    sign_in @active_user

    assert_no_difference "AccountDeletionRequest.count" do
      post request_deletion_profile_path
    end

    assert_redirected_to edit_profile_path
  end

  test "cancel deletion request marks active request as canceled" do
    request = @active_user.account_deletion_requests.create!(
      status: :pending,
      requested_at: Time.current,
      scheduled_for: 7.days.from_now
    )
    sign_in @active_user

    freeze_time do
      delete cancel_deletion_request_profile_path
      assert_redirected_to edit_profile_path
      assert_equal "canceled", request.reload.status
      assert_equal Time.current, request.canceled_at
    end
  end
end
