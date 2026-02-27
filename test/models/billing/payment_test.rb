# frozen_string_literal: true

require "test_helper"

module Billing
  class PaymentTest < ActiveSupport::TestCase
    def valid_attrs
      {
        subscription: subscriptions(:one),
        space: spaces(:one),
        asaas_payment_id: "pay_unique_#{SecureRandom.hex(4)}",
        amount_cents: 9900,
        payment_method: :pix,
        status: :pending
      }
    end

    test "valid payment can be created" do
      payment = Billing::Payment.new(valid_attrs)
      assert payment.valid?
    end

    test "asaas_payment_id uniqueness is enforced" do
      existing = payments(:one)
      dup = Billing::Payment.new(valid_attrs.merge(asaas_payment_id: existing.asaas_payment_id))
      assert_not dup.valid?
      assert_includes dup.errors[:asaas_payment_id], I18n.t("errors.messages.taken")
    end

    test "asaas_payment_id is required" do
      payment = Billing::Payment.new(valid_attrs.merge(asaas_payment_id: nil))
      assert_not payment.valid?
    end

    test "amount_cents must be positive" do
      payment = Billing::Payment.new(valid_attrs.merge(amount_cents: 0))
      assert_not payment.valid?
      assert payment.errors[:amount_cents].any?
    end

    test "amount_cents cannot be negative" do
      payment = Billing::Payment.new(valid_attrs.merge(amount_cents: -100))
      assert_not payment.valid?
    end

    test "status enum resolves pending" do
      payment = Billing::Payment.new(valid_attrs.merge(status: :pending))
      assert payment.pending?
    end

    test "status enum resolves confirmed" do
      payment = Billing::Payment.new(valid_attrs.merge(status: :confirmed))
      assert payment.confirmed?
    end
  end
end
