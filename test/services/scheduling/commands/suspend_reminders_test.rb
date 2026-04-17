# frozen_string_literal: true

require "test_helper"

class Scheduling::Commands::SuspendRemindersTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::ConstantStubbing

  setup do
    @space = spaces(:one)
    @other_space = spaces(:two)
    @customer = customers(:one)
    @actor = users(:manager)
  end

  teardown do
    AppointmentEvent.where("idempotency_key LIKE ?", "test-scheduling-suspend-reminders-%").delete_all
  end

  test "suspends reminders for a single appointment even when AppointmentReminder is unavailable" do
    appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now)

    travel_to Time.zone.parse("2026-04-17 11:15:00") do
      result = Scheduling::Commands::SuspendReminders.for_appointment(
        space: @space,
        appointment_id: appointment.id,
        actor: @actor,
        reason: "cancelled_elsewhere",
        idempotency_key: "test-scheduling-suspend-reminders-appointment"
      )

      assert_predicate result, :ok?

      event = AppointmentEvent.find_by!(idempotency_key: "test-scheduling-suspend-reminders-appointment:#{appointment.id}")

      assert_equal "reminders.suspended", event.event_type
      assert_equal @space, event.space
      assert_equal appointment, event.appointment
      assert_equal(
        { "reason" => "cancelled_elsewhere", "superseded_count" => 0 },
        event.metadata
      )
    end
  end

  test "suspends reminders for all active appointments of a customer and revokes whatsapp consent" do
    customer = @space.customers.create!(
      name: "Opt Out Customer",
      email: "opt-out@example.com",
      phone: "+5511999990222",
      address: "Rua Opt Out, 10"
    )
    active_one = create_appointment(customer: customer, status: :pending, scheduled_at: 2.days.from_now)
    active_two = create_appointment(customer: customer, status: :confirmed, scheduled_at: 3.days.from_now)
    rescheduled = create_appointment(customer: customer, status: :rescheduled, scheduled_at: 4.days.from_now)
    create_appointment(customer: customer, status: :cancelled, scheduled_at: 5.days.from_now)
    create_appointment(customer: customer, status: :finished, scheduled_at: 1.day.ago)
    outsider = create_appointment(
      space: @other_space,
      customer: customers(:other_space_customer),
      status: :confirmed,
      scheduled_at: 2.days.from_now
    )

    customer.update!(
      whatsapp_opted_in_at: 2.days.ago,
      whatsapp_opt_in_source: "booking_form",
      whatsapp_opted_out_at: nil,
      whatsapp_opt_out_source: nil
    )

    freeze_time do
      result = Scheduling::Commands::SuspendReminders.for_customer(
        space: @space,
        customer: customer,
        actor: @actor,
        reason: "opt_out_keyword",
        idempotency_key: "test-scheduling-suspend-reminders-customer"
      )

      assert_predicate result, :ok?

      customer.reload
      assert_equal Time.current, customer.whatsapp_opted_out_at
      assert_equal "whatsapp_reply", customer.whatsapp_opt_out_source

      events = AppointmentEvent.where("idempotency_key LIKE ?", "test-scheduling-suspend-reminders-customer:%").order(:appointment_id)

      assert_equal [ active_one.id, active_two.id, rescheduled.id ], events.pluck(:appointment_id)
      assert_empty AppointmentEvent.where(appointment: outsider)
      assert events.all? { |event| event.event_type == "reminders.suspended" }
      assert events.all? { |event| event.metadata == { "reason" => "opt_out_keyword", "superseded_count" => 0 } }
    end
  end

  test "does not revoke consent when revoke_consent is false" do
    appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now)
    @customer.update!(
      whatsapp_opted_in_at: 2.days.ago,
      whatsapp_opt_in_source: "booking_form",
      whatsapp_opted_out_at: nil,
      whatsapp_opt_out_source: nil
    )

    Scheduling::Commands::SuspendReminders.new(
      space: @space,
      actor: @actor,
      reason: "reschedule_flow",
      idempotency_key: "test-scheduling-suspend-reminders-no-revoke",
      appointment_ids: [ appointment.id ],
      customer: @customer,
      revoke_consent: false
    ).call

    @customer.reload
    assert_nil @customer.whatsapp_opted_out_at
    assert_nil @customer.whatsapp_opt_out_source
  end

  test "replays successfully for the same idempotency key without duplicating events" do
    appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now)
    idempotency_key = "test-scheduling-suspend-reminders-replay"

    first = Scheduling::Commands::SuspendReminders.for_appointment(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      reason: "cancelled_elsewhere",
      idempotency_key: idempotency_key
    )

    second = Scheduling::Commands::SuspendReminders.for_appointment(
      space: @space,
      appointment_id: appointment.id,
      actor: @actor,
      reason: "customer_opt_out",
      idempotency_key: idempotency_key
    )

    assert_predicate first, :ok?
    assert_predicate second, :ok?
    assert_equal 1, AppointmentEvent.where(idempotency_key: "#{idempotency_key}:#{appointment.id}").count
  end

  test "scopes reminder updates by tenant, appointment ids, and open statuses when AppointmentReminder exists" do
    appointment = create_appointment(status: :confirmed, scheduled_at: 2.days.from_now)
    fake_reminder_model = Class.new do
      class << self
        attr_reader :calls
      end

      @calls = []

      def self.statuses
        { superseded: 3 }
      end

      def self.where(criteria)
        @calls << criteria
        FakeReminderRelation.new(@calls)
      end
    end

    stub_const(Object, :AppointmentReminder, fake_reminder_model) do
      result = Scheduling::Commands::SuspendReminders.for_appointment(
        space: @space,
        appointment_id: appointment.id,
        actor: @actor,
        reason: "cancelled_elsewhere",
        idempotency_key: "test-scheduling-suspend-reminders-reminder-scope"
      )

      assert_predicate result, :ok?
      assert_equal(
        [
          { space_id: @space.id, appointment_id: [ appointment.id ] },
          { status: %w[scheduled queued] }
        ],
        fake_reminder_model.calls
      )

      event = AppointmentEvent.find_by!(idempotency_key: "test-scheduling-suspend-reminders-reminder-scope:#{appointment.id}")
      assert_equal 3, event.metadata["superseded_count"]
    end
  end

  private

  FakeReminderRelation = Struct.new(:calls) do
    def initialize(calls = nil)
      super(calls || [])
    end

    def where(criteria)
      calls << criteria
      self
    end

    def update_all(attributes)
      unless attributes[:status] == 3 && attributes[:updated_at].is_a?(Time)
        raise "unexpected update_all attributes: #{attributes.inspect}"
      end

      3
    end
  end

  def create_appointment(space: @space, customer: @customer, status:, scheduled_at:)
    space.appointments.create!(
      customer: customer,
      scheduled_at: scheduled_at,
      status: status,
      duration_minutes: 30,
      confirmation_state: :awaiting_customer
    )
  end
end
