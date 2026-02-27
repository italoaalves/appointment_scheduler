# frozen_string_literal: true

require "test_helper"

module Billing
  class MessageCreditTest < ActiveSupport::TestCase
    def valid_attrs
      { space: spaces(:one), balance: 0, monthly_quota_remaining: 0 }
    end

    test "valid message credit can be created" do
      credit = Billing::MessageCredit.new(valid_attrs.merge(space: spaces(:two)))
      assert credit.valid?
    end

    test "space_id uniqueness is enforced" do
      existing = message_credits(:one)
      dup = Billing::MessageCredit.new(valid_attrs.merge(space: existing.space))
      assert_not dup.valid?
      assert_includes dup.errors[:space_id], I18n.t("errors.messages.taken")
    end

    test "balance cannot be negative" do
      credit = Billing::MessageCredit.new(valid_attrs.merge(balance: -1))
      assert_not credit.valid?
      assert credit.errors[:balance].any?
    end

    test "balance can be zero" do
      credit = Billing::MessageCredit.new(valid_attrs.merge(space: spaces(:two), balance: 0))
      assert credit.valid?
    end

    test "monthly_quota_remaining cannot be negative" do
      credit = Billing::MessageCredit.new(valid_attrs.merge(monthly_quota_remaining: -1))
      assert_not credit.valid?
      assert credit.errors[:monthly_quota_remaining].any?
    end

    test "monthly_quota_remaining can be zero" do
      credit = Billing::MessageCredit.new(valid_attrs.merge(space: spaces(:two), monthly_quota_remaining: 0))
      assert credit.valid?
    end
  end
end
