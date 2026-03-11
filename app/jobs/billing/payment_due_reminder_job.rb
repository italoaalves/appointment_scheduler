# frozen_string_literal: true

module Billing
  class PaymentDueReminderJob < ApplicationJob
    queue_as :default

    def perform
      remind_payments(due_date: Date.current + 3.days, reminder_type: "approaching")
      remind_payments(due_date: Date.current,           reminder_type: "due_today")
      remind_payments(due_date: Date.current - 1.day,  reminder_type: "overdue")
    end

    private

    def remind_payments(due_date:, reminder_type:)
      pending_pix_boleto_payments
        .where(due_date: due_date)
        .find_each do |payment|
          Billing::PaymentReminderJob.perform_later(payment.id, reminder_type: reminder_type)
        end
    end

    def pending_pix_boleto_payments
      Billing::Payment
        .where(status: :pending)
        .where(payment_method: [ :pix, :boleto ])
    end
  end
end
