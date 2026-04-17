# frozen_string_literal: true

require "test_helper"
require_dependency "scheduling/commands/base"

class Scheduling::Commands::BaseTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  class NoopCommand < Scheduling::Commands::Base
    class_attribute :lock_observed, default: false
    class_attribute :broadcasts, default: []
    class_attribute :broadcast_mutex, default: Mutex.new

    def mutate!(appointment)
      lock_key = Zlib.crc32("scheduling:#{appointment.id}")

      self.class.lock_observed = Appointment.connection.select_value(
        <<~SQL.squish
          SELECT EXISTS (
            SELECT 1
            FROM pg_locks
            WHERE locktype = 'advisory'
              AND pid = pg_backend_pid()
              AND classid = 0
              AND objid = #{lock_key}
              AND objsubid = 1
          )
        SQL
      )
    end

    def event_type
      "appointment.noop"
    end

    def broadcast(_appointment)
      self.class.broadcast_mutex.synchronize do
        self.class.broadcasts = self.class.broadcasts + [ @space.id ]
      end
    end
  end

  class GuardedCommand < NoopCommand
    def guard(appointment)
      Result.err(error: :guard_failed, appointment: appointment)
    end
  end

  setup do
    @space = spaces(:one)
    @appointment = appointments(:one)
    @actor = users(:manager)
    NoopCommand.lock_observed = false
    NoopCommand.broadcasts = []
  end

  teardown do
    AppointmentEvent.where("idempotency_key LIKE ?", "test-scheduling-base-%").delete_all
    NoopCommand.lock_observed = false
    NoopCommand.broadcasts = []
  end

  test "returns ok result and writes appointment event for successful command" do
    result = nil

    assert_difference("AppointmentEvent.count", 1) do
      result = NoopCommand.call(
        space: @space,
        appointment_id: @appointment.id,
        actor: @actor,
        idempotency_key: "test-scheduling-base-success",
        metadata: { "source" => "test" }
      )
    end

    event = AppointmentEvent.find(result.event_id)

    assert_predicate result, :ok?
    assert_equal @appointment, result.appointment
    assert_equal "appointment.noop", event.event_type
    assert_equal @space, event.space
    assert_equal @appointment, event.appointment
    assert_equal "User", event.actor_type
    assert_equal @actor.id, event.actor_id
    assert_equal({ "source" => "test" }, event.metadata)
    assert_equal [ @space.id ], NoopCommand.broadcasts
  end

  test "returns appointment_not_found when appointment is outside the given space" do
    result = NoopCommand.call(
      space: spaces(:two),
      appointment_id: @appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-base-missing"
    )

    assert_not result.ok?
    assert_equal :appointment_not_found, result.error
    assert_nil result.appointment
  end

  test "acquires the advisory lock inside the transaction" do
    NoopCommand.call(
      space: @space,
      appointment_id: @appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-base-lock"
    )

    assert_equal true, NoopCommand.lock_observed
  end

  test "broadcasts once on success and not on guard failure" do
    NoopCommand.call(
      space: @space,
      appointment_id: @appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-base-broadcast-success"
    )

    result = GuardedCommand.call(
      space: @space,
      appointment_id: @appointment.id,
      actor: @actor,
      idempotency_key: "test-scheduling-base-broadcast-guard"
    )

    assert_not result.ok?
    assert_equal :guard_failed, result.error
    assert_equal [ @space.id ], NoopCommand.broadcasts
  end

  test "concurrent calls with the same idempotency key return the same successful result" do
    idempotency_key = "test-scheduling-base-concurrent-#{SecureRandom.hex(6)}"
    ready = Queue.new
    gate = Queue.new
    results = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          gate.pop

          results << NoopCommand.call(
            space: @space,
            appointment_id: @appointment.id,
            actor: @actor,
            idempotency_key: idempotency_key
          )
        end
      end
    end

    2.times { ready.pop }
    2.times { gate << true }
    threads.each(&:join)

    first = results.pop
    second = results.pop
    event = AppointmentEvent.find_by!(idempotency_key: idempotency_key)

    assert_equal 1, AppointmentEvent.where(idempotency_key: idempotency_key).count
    assert_predicate first, :ok?
    assert_predicate second, :ok?
    assert_equal event.id, first.event_id
    assert_equal event.id, second.event_id
    assert_equal @appointment, first.appointment
    assert_equal @appointment, second.appointment
    assert_equal [ @space.id ], NoopCommand.broadcasts
  end
end
