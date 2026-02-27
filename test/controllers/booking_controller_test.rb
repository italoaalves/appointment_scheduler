# frozen_string_literal: true

require "test_helper"

class BookingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @space = spaces(:one)
    @link = scheduling_links(:permanent_link)
    @single_use = scheduling_links(:single_use_link)
  end

  test "show renders booking page for valid token" do
    get book_url(token: @link.token)
    assert_response :success
  end

  test "show returns 404 for invalid token" do
    get book_url(token: "nonexistent")
    assert_response :not_found
  end

  test "show returns gone for expired link" do
    expired = scheduling_links(:expired_link)
    get book_url(token: expired.token)
    assert_response :gone
  end

  test "show returns gone for used single-use link" do
    used = scheduling_links(:used_link)
    get book_url(token: used.token)
    assert_response :gone
  end

  test "slots returns JSON" do
    get book_slots_url(token: @link.token), as: :json
    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "create with valid data creates appointment" do
    scheduled = 3.days.from_now.change(hour: 10, min: 0, sec: 0)
    assert_difference "Appointment.count", 1 do
      post "/book/#{@link.token}", params: {
        customer_name: "Test Person",
        customer_email: "test@example.com",
        customer_phone: "+5511999999999",
        scheduled_at: scheduled.strftime("%Y-%m-%d %H:%M")
      }
    end
    assert_response :redirect
  end

  test "create enqueues appointment_booked notification" do
    scheduled = 3.days.from_now.change(hour: 10, min: 0, sec: 0)

    assert_enqueued_with(job: Notifications::SendNotificationJob) do
      post "/book/#{@link.token}", params: {
        customer_name: "Test Person",
        customer_email: "test@example.com",
        customer_phone: "+5511999999999",
        scheduled_at: scheduled.strftime("%Y-%m-%d %H:%M")
      }
    end
    assert_response :redirect
  end

  test "create with blank scheduled_at returns error" do
    post "/book/#{@link.token}", params: {
      customer_name: "Test Person",
      customer_email: "test@example.com",
      scheduled_at: ""
    }
    assert_response :unprocessable_entity
  end

  test "single-use link is marked as used after booking" do
    scheduled = 3.days.from_now.change(hour: 14, min: 0, sec: 0)
    post "/book/#{@single_use.token}", params: {
      customer_name: "Single Use Test",
      customer_email: "singleuse@example.com",
      scheduled_at: scheduled.strftime("%Y-%m-%d %H:%M")
    }
    @single_use.reload
    assert_not_nil @single_use.used_at
  end

  test "thank_you page renders for valid token" do
    get thank_you_book_url(token: @link.token)
    assert_response :success
  end

  # ── Subscription restriction ──────────────────────────────────────────────

  test "show returns service_unavailable when space subscription is expired" do
    subscriptions(:one).update!(status: :expired)

    get book_url(token: @link.token)
    assert_response :service_unavailable
  end

  test "show renders normally when space subscription is active" do
    subscriptions(:one).update!(status: :active)

    get book_url(token: @link.token)
    assert_response :success
  end

  test "show renders normally when space has no subscription" do
    sub = subscriptions(:one)
    Billing::BillingEvent.where(subscription_id: sub.id).delete_all
    Billing::Payment.where(subscription_id: sub.id).delete_all
    sub.delete
    @space.reload

    get book_url(token: @link.token)
    assert_response :success
  end
end
