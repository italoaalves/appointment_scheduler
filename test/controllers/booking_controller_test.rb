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

  test "show renders a centered guided booking flow with sticky hero and reactive step cards" do
    get book_url(token: @link.token)

    assert_response :success
    assert_select "body.booking-shell"
    assert_select ".booking-page"
    assert_select ".booking-flow-shell"
    assert_select ".booking-hero-sticky"
    assert_select "[data-role='booking-hero']"
    assert_select "[data-role='booking-composer']"
    assert_select "[data-role='booking-summary-card']"
    assert_select "[data-booking-target='flowStep']", count: 3
    assert_select "[data-step-name='schedule']"
    assert_select "[data-step-name='details']"
    assert_select "[data-step-name='review']"
    assert_select "[data-role='booking-date-picker']"
    assert_select "[data-role='booking-slot-picker']"
    assert_select "[data-booking-target='slotsContainer'][data-morning-text]"
    assert_select "template [data-slot-context]"
    assert_select "template .booking-slot-option-indicator-core"
    assert_select "[data-booking-target='slotsSync']"
    assert_select "[data-role='booking-optional-details-panel']"
    assert_select "[data-role='booking-consent-panel']"
    assert_select "[data-role='booking-action-bar']"
    assert_select "[data-booking-target='summaryPlaceholder']", /#{Regexp.escape(I18n.t("booking.summary.placeholder"))}/
    assert_select "[data-role='booking-contact-hint']", I18n.t("booking.details_hint")
  end

  test "show uses the effective availability timezone across the booking flow" do
    @space.create_availability_schedule!(timezone: "America/New_York")

    get book_url(token: @link.token)

    assert_response :success
    assert_match I18n.t("booking.choose_date_hint", timezone: "America/New_York"), response.body
    assert_match "America/New_York", response.body
  end

  test "show no longer relies on inline body styling" do
    get book_url(token: @link.token)

    assert_response :success
    assert_no_match(/<body[^>]*style=/, response.body)
  end

  test "show includes optional whatsapp consent checkbox" do
    get book_url(token: @link.token)

    assert_response :success
    assert_select "input[name='whatsapp_opt_in'][type='checkbox']"
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
        whatsapp_opt_in: "1",
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
        whatsapp_opt_in: "1",
        scheduled_at: scheduled.strftime("%Y-%m-%d %H:%M")
      }
    end
    assert_response :redirect
  end

  test "create records whatsapp consent when customer opts in" do
    scheduled = 3.days.from_now.change(hour: 11, min: 0, sec: 0)

    freeze_time do
      post "/book/#{@link.token}", params: {
        customer_name: "Consent Customer",
        customer_email: "consent_customer@example.com",
        customer_phone: "+5511999999988",
        whatsapp_opt_in: "1",
        scheduled_at: scheduled.strftime("%Y-%m-%d %H:%M")
      }

      customer = Customer.find_by!(email: "consent_customer@example.com")
      assert customer.whatsapp_opted_in?
      assert_equal Time.current, customer.whatsapp_opted_in_at
      assert_equal "booking_form", customer.whatsapp_opt_in_source
    end
  end

  test "create does not record whatsapp consent when customer leaves it unchecked" do
    scheduled = 3.days.from_now.change(hour: 12, min: 0, sec: 0)

    post "/book/#{@link.token}", params: {
      customer_name: "No Consent Customer",
      customer_email: "no_consent_customer@example.com",
      customer_phone: "+5511999999987",
      whatsapp_opt_in: "0",
      scheduled_at: scheduled.strftime("%Y-%m-%d %H:%M")
    }

    customer = Customer.find_by!(email: "no_consent_customer@example.com")
    assert_not customer.whatsapp_opted_in?
    assert_nil customer.whatsapp_opted_in_at
  end

  test "create with blank scheduled_at returns error" do
    post "/book/#{@link.token}", params: {
      customer_name: "Test Person",
      customer_email: "test@example.com",
      scheduled_at: ""
    }
    assert_response :unprocessable_entity
  end

  test "create preserves in-progress booking details when the selected slot becomes invalid" do
    @space.update!(request_max_days_ahead: 1)
    scheduled = 3.days.from_now.change(hour: 10, min: 0, sec: 0)

    post "/book/#{@link.token}", params: {
      customer_name: "Taylor Test",
      customer_phone: "+5511999999999",
      customer_address: "123 Calm Street",
      date: scheduled.to_date.iso8601,
      scheduled_at: scheduled.strftime("%Y-%m-%d %H:%M")
    }

    assert_response :unprocessable_entity
    assert_select "input#customer_name[value='Taylor Test']"
    assert_select "input#customer_phone[value='+5511999999999']"
    assert_select "input#customer_address[value='123 Calm Street']"
    assert_select "input#booking_date[value='#{scheduled.to_date.iso8601}']"
    assert_select "input[data-booking-target='scheduledAt'][value='#{scheduled.strftime("%Y-%m-%d %H:%M")}']"
  end

  test "single-use link is marked as used after booking" do
    scheduled = 3.days.from_now.change(hour: 14, min: 0, sec: 0)
    post "/book/#{@single_use.token}", params: {
      customer_name: "Single Use Test",
      customer_email: "singleuse@example.com",
      whatsapp_opt_in: "0",
      scheduled_at: scheduled.strftime("%Y-%m-%d %H:%M")
    }
    @single_use.reload
    assert_not_nil @single_use.used_at
  end

  test "thank_you page renders for valid token" do
    get thank_you_book_url(token: @link.token)
    assert_response :success
  end

  test "thank_you page reuses the public booking shell and summary card" do
    get thank_you_book_url(token: @link.token)

    assert_response :success
    assert_select "body.booking-shell"
    assert_select ".booking-page"
    assert_select "[data-role='booking-hero']"
    assert_select "[data-role='booking-summary-card']"
    assert_select "[data-role='booking-confirmation-card']"
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

  test "invalid link uses the shared public state card" do
    get book_url(token: "nonexistent")

    assert_response :not_found
    assert_select "body.booking-shell"
    assert_select ".booking-page"
    assert_select "[data-role='booking-state-card']"
  end

  test "expired link uses the shared public state card" do
    expired = scheduling_links(:expired_link)

    get book_url(token: expired.token)

    assert_response :gone
    assert_select "body.booking-shell"
    assert_select ".booking-page"
    assert_select "[data-role='booking-state-card']"
  end

  test "unavailable link uses the shared public state card" do
    subscriptions(:one).update!(status: :expired)

    get book_url(token: @link.token)

    assert_response :service_unavailable
    assert_select "body.booking-shell"
    assert_select ".booking-page"
    assert_select "[data-role='booking-state-card']"
  end

  test "unexpected html errors render a safe fallback and report context" do
    with_swapped_action(BookingController, :show, proc { raise RuntimeError, "boom" }) do
      report = assert_error_reported(RuntimeError) do
        get book_url(token: @link.token)
      end

      assert_response :internal_server_error
      assert_match I18n.t("errors.internal_server_error.message"), response.body
      assert_match(/#{Regexp.escape(report.context["request_id"])}/, response.body)
      assert_equal "application.controller", report.source
      assert_equal false, report.handled?
      assert_equal "[FILTERED]", report.context["params"]["token"]
      assert_equal "booking", report.context["controller"]
      assert_equal "show", report.context["action"]
    end
  end

  test "unexpected json errors render a safe fallback and report filtered params" do
    with_swapped_action(BookingController, :slots, proc { raise RuntimeError, "customer maria failed" }) do
      report = assert_error_reported(RuntimeError) do
        get book_slots_url(token: @link.token), params: { customer_email: "maria@example.com" }, as: :json
      end

      assert_response :internal_server_error
      assert_equal "application/json", response.media_type
      body = JSON.parse(response.body)

      assert_equal I18n.t("errors.internal_server_error.message"), body["error"]
      assert_equal report.context["request_id"], body["request_id"]
      assert_equal "[FILTERED]", report.context["params"]["customer_email"]
      assert_equal "json", report.context["format"]
    end
  end

  private

  def with_swapped_action(controller_class, action_name, replacement)
    original_method = controller_class.instance_method(action_name)

    controller_class.define_method(action_name, &replacement)
    yield
  ensure
    controller_class.define_method(action_name, original_method)
  end
end
