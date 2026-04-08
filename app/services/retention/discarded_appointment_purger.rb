# frozen_string_literal: true

module Retention
  class DiscardedAppointmentPurger
    BATCH_SIZE = 100
    RETENTION_PERIOD = 30.days

    def self.call(cutoff: RETENTION_PERIOD.ago)
      new(cutoff:).call
    end

    def initialize(cutoff:)
      @cutoff = cutoff
    end

    def call
      deleted_count = 0

      eligible_scope.in_batches(of: BATCH_SIZE) do |relation|
        appointment_ids = relation.pluck(:id)
        next if appointment_ids.empty?

        Appointment.transaction do
          Message.where(messageable_type: "Appointment", messageable_id: appointment_ids).delete_all
          Notification.where(notifiable_type: "Appointment", notifiable_id: appointment_ids).delete_all
          deleted_count += Appointment.unscoped.where(id: appointment_ids).delete_all
        end
      end

      deleted_count
    end

    private

    def eligible_scope
      Appointment.unscoped
        .where.not(discarded_at: nil)
        .where(discarded_at: ..@cutoff)
    end
  end
end
