# frozen_string_literal: true

require "test_helper"

module Inbox
  class SlaPolicyTest < ActiveSupport::TestCase
    # --- deadline_for ---

    test "deadline_for urgent is 15 minutes from now" do
      freeze_time do
        assert_equal Time.current + 15.minutes, SlaPolicy.deadline_for(:urgent)
      end
    end

    test "deadline_for high is 1 hour from now" do
      freeze_time do
        assert_equal Time.current + 1.hour, SlaPolicy.deadline_for(:high)
      end
    end

    test "deadline_for normal is 4 hours from now" do
      freeze_time do
        assert_equal Time.current + 4.hours, SlaPolicy.deadline_for(:normal)
      end
    end

    test "deadline_for low is 24 hours from now" do
      freeze_time do
        assert_equal Time.current + 24.hours, SlaPolicy.deadline_for(:low)
      end
    end

    test "deadline_for accepts a custom from time" do
      base = 1.hour.ago
      assert_equal base + 4.hours, SlaPolicy.deadline_for(:normal, from: base)
    end

    test "deadline_for falls back to normal for unknown priority" do
      freeze_time do
        assert_equal Time.current + 4.hours, SlaPolicy.deadline_for(:unknown_priority)
      end
    end

    # --- breached? ---

    test "breached? returns false when first_response_at is present" do
      conversation = build_conversation(
        sla_deadline_at: 1.hour.ago,
        first_response_at: 30.minutes.ago
      )
      assert_not SlaPolicy.breached?(conversation)
    end

    test "breached? returns false when sla_deadline_at is nil" do
      conversation = build_conversation(
        sla_deadline_at: nil,
        first_response_at: nil
      )
      assert_not SlaPolicy.breached?(conversation)
    end

    test "breached? returns false when deadline is in the future" do
      conversation = build_conversation(
        sla_deadline_at: 1.hour.from_now,
        first_response_at: nil
      )
      assert_not SlaPolicy.breached?(conversation)
    end

    test "breached? returns true when deadline passed and no response" do
      conversation = build_conversation(
        sla_deadline_at: 1.minute.ago,
        first_response_at: nil
      )
      assert SlaPolicy.breached?(conversation)
    end

    private

    def build_conversation(sla_deadline_at:, first_response_at:)
      OpenStruct.new(sla_deadline_at: sla_deadline_at, first_response_at: first_response_at)
    end
  end
end
