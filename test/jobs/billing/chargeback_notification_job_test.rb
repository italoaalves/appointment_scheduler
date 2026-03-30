# frozen_string_literal: true

require "test_helper"

module Billing
  class ChargebackNotificationJobTest < ActiveJob::TestCase
    include ActionMailer::TestHelper

    setup do
      @space = spaces(:one)
      @subscription = @space.subscription
      @payment = Billing::Payment.create!(
        asaas_payment_id: "pay_cb_job_001",
        subscription:     @subscription,
        space_id:         @space.id,
        amount_cents:     9900,
        payment_method:   :credit_card,
        status:           :confirmed
      )
      @super_admin = User.find_by(system_role: :super_admin) ||
                     User.create!(
                       name:        "Super Admin",
                       email:       "superadmin_cb_test@example.com",
                       password:    "password123",
                       system_role: :super_admin
                     )
    end

    test "sends email to every super admin" do
      assert_emails 1 do
        Billing::ChargebackNotificationJob.perform_now(
          @payment.id, "PAYMENT_CHARGEBACK_REQUESTED", "Fraud"
        )
      end

      email = ActionMailer::Base.deliveries.last
      assert_equal [ @super_admin.email ], email.to
      assert_match "PAYMENT_CHARGEBACK_REQUESTED", email.subject
      assert_match @space.name, email.subject
    end

    test "logs a notification BillingEvent" do
      assert_difference "Billing::BillingEvent.count", 1 do
        Billing::ChargebackNotificationJob.perform_now(
          @payment.id, "PAYMENT_CHARGEBACK_REQUESTED", "Fraud"
        )
      end

      event = Billing::BillingEvent.find_by(event_type: "notification.payment_chargeback_requested")
      assert_not_nil event
      assert_equal @payment.asaas_payment_id, event.metadata["asaas_payment_id"]
    end

    test "is idempotent — retrying does not send duplicate emails" do
      Billing::ChargebackNotificationJob.perform_now(@payment.id, "PAYMENT_CHARGEBACK_REQUESTED", "Fraud")

      assert_no_emails do
        Billing::ChargebackNotificationJob.perform_now(@payment.id, "PAYMENT_CHARGEBACK_REQUESTED", "Fraud")
      end
    end

    test "is idempotent — retrying does not create duplicate BillingEvent" do
      Billing::ChargebackNotificationJob.perform_now(@payment.id, "PAYMENT_CHARGEBACK_REQUESTED", "Fraud")

      assert_no_difference "Billing::BillingEvent.count" do
        Billing::ChargebackNotificationJob.perform_now(@payment.id, "PAYMENT_CHARGEBACK_REQUESTED", "Fraud")
      end
    end
  end
end
