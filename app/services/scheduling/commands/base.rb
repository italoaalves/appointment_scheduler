# frozen_string_literal: true

module Scheduling
  module Commands
    class Base
      Result = Struct.new(:ok?, :appointment, :error, :event_id, keyword_init: true) do
        def self.ok(appointment:, event_id:)
          new(ok?: true, appointment: appointment, event_id: event_id)
        end

        def self.err(error:, appointment: nil)
          new(ok?: false, error: error, appointment: appointment)
        end
      end

      SystemActor = Data.define(:label) do
        def id = nil
        def class = "System"
      end

      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(space:, appointment_id:, actor:, idempotency_key:, metadata: {})
        @space = space
        @appointment_id = appointment_id
        @actor = actor
        @idempotency_key = idempotency_key
        @metadata = metadata
      end

      def call
        ActiveRecord::Base.transaction do
          acquire_advisory_lock!

          appointment = @space.appointments.find(@appointment_id)
          replay = replay_result_for(appointment)
          return replay if replay

          guard_result = guard(appointment)
          return guard_result if guard_result&.ok? == false

          mutate!(appointment)

          event = AppointmentEvent.create!(
            space: @space,
            appointment: appointment,
            event_type: event_type,
            actor_type: actor_type,
            actor_id: actor_id,
            actor_label: actor_label,
            idempotency_key: @idempotency_key,
            metadata: @metadata
          )

          broadcast(appointment)
          Result.ok(appointment: appointment, event_id: event.id)
        end
      rescue ActiveRecord::RecordNotUnique => e
        raise unless e.message.include?("idempotency_key")

        existing = AppointmentEvent.find_by!(idempotency_key: @idempotency_key)

        Result.ok(
          appointment: @space.appointments.find(existing.appointment_id),
          event_id: existing.id
        )
      rescue ActiveRecord::RecordNotFound
        Result.err(error: :appointment_not_found)
      end

      private

      def mutate!(_appointment)
        raise NotImplementedError
      end

      def event_type
        raise NotImplementedError
      end

      def guard(_appointment)
        nil
      end

      def broadcast(_appointment)
        DashboardCalendarBroadcaster.broadcast_for(space: @space)
      end

      def replay_result_for(appointment)
        existing = AppointmentEvent.find_by(
          space: @space,
          appointment: appointment,
          event_type: event_type,
          idempotency_key: @idempotency_key
        )
        return unless existing

        Result.ok(appointment: appointment, event_id: existing.id)
      end

      def acquire_advisory_lock!
        key = Zlib.crc32("scheduling:#{@appointment_id}")
        ApplicationRecord.execute_void_query(
          "SELECT pg_advisory_xact_lock($1)", "AdvisoryLock", [ key ]
        )
      end

      def actor_id
        @actor.respond_to?(:id) ? @actor.id : nil
      end

      def actor_type
        @actor.class.to_s
      end

      def actor_label
        @actor.respond_to?(:label) ? @actor.label : nil
      end
    end
  end
end
