# frozen_string_literal: true

module Scheduling
  module Commands
    class SuspendReminders
      Result = Base::Result
      SystemActor = Base::SystemActor

      def self.for_appointment(space:, appointment_id:, actor:, reason:, idempotency_key:)
        new(
          space: space,
          actor: actor,
          reason: reason,
          idempotency_key: idempotency_key,
          appointment_ids: [ appointment_id ]
        ).call
      end

      def self.for_customer(space:, customer:, actor:, reason:, idempotency_key:, revoke_consent: true)
        appointment_ids = space.appointments
          .where(customer_id: customer.id, status: %w[pending confirmed rescheduled])
          .ids

        new(
          space: space,
          actor: actor,
          reason: reason,
          idempotency_key: idempotency_key,
          appointment_ids: appointment_ids,
          customer: customer,
          revoke_consent: revoke_consent
        ).call
      end

      def initialize(space:, actor:, reason:, idempotency_key:, appointment_ids:, customer: nil, revoke_consent: false)
        @space = space
        @actor = actor
        @reason = reason
        @idempotency_key = idempotency_key
        @appointment_ids = appointment_ids
        @customer = customer
        @revoke_consent = revoke_consent
      end

      def call
        ActiveRecord::Base.transaction do
          revoke_customer_consent! if @revoke_consent && @customer.present?

          superseded_count = supersede_reminders!

          @appointment_ids.each do |appointment_id|
            AppointmentEvent.create!(
              space: @space,
              appointment_id: appointment_id,
              event_type: "reminders.suspended",
              actor_type: actor_type,
              actor_id: actor_id,
              actor_label: actor_label,
              idempotency_key: "#{@idempotency_key}:#{appointment_id}",
              metadata: { reason: @reason, superseded_count: superseded_count }
            )
          end

          Result.ok(appointment: nil, event_id: nil)
        end
      rescue ActiveRecord::RecordNotUnique => error
        raise unless error.message.include?("idempotency_key")

        Result.ok(appointment: nil, event_id: nil)
      end

      private

      def revoke_customer_consent!
        @customer.revoke_whatsapp_consent(source: :whatsapp_reply)
        @customer.save!
      end

      def supersede_reminders!
        return 0 unless defined?(AppointmentReminder)
        return 0 if @appointment_ids.empty?

        AppointmentReminder
          .where(space_id: @space.id, appointment_id: @appointment_ids)
          .where(status: %w[scheduled queued])
          .update_all(
            status: superseded_status,
            updated_at: Time.current
          )
      end

      def superseded_status
        return AppointmentReminder.statuses[:superseded] if AppointmentReminder.respond_to?(:statuses)

        "superseded"
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
