# frozen_string_literal: true

require "test_helper"

class WhatsappPhoneNumberTest < ActiveSupport::TestCase
  # ── Validations ───────────────────────────────────────────────────────────────

  test "is valid with all required attributes" do
    pn = WhatsappPhoneNumber.new(
      phone_number_id: "unique_phone_id",
      display_number: "+55 11 00000-0001",
      waba_id: "waba_001"
    )
    assert pn.valid?
  end

  test "validates presence of phone_number_id" do
    pn = WhatsappPhoneNumber.new(display_number: "+55 11 00000-0001", waba_id: "waba_001")
    assert_not pn.valid?
    assert pn.errors[:phone_number_id].any?
  end

  test "validates presence of display_number" do
    pn = WhatsappPhoneNumber.new(phone_number_id: "unique_id", waba_id: "waba_001")
    assert_not pn.valid?
    assert pn.errors[:display_number].any?
  end

  test "validates presence of waba_id" do
    pn = WhatsappPhoneNumber.new(phone_number_id: "unique_id", display_number: "+55 11 00000-0001")
    assert_not pn.valid?
    assert pn.errors[:waba_id].any?
  end

  test "validates uniqueness of phone_number_id" do
    pn = WhatsappPhoneNumber.new(
      phone_number_id: whatsapp_phone_numbers(:system_bot).phone_number_id,
      display_number: "+55 11 00000-0001",
      waba_id: "waba_001"
    )
    assert_not pn.valid?
    assert pn.errors[:phone_number_id].any?
  end

  test "validates uniqueness of space_id" do
    pn = WhatsappPhoneNumber.new(
      phone_number_id: "another_phone_id",
      display_number: "+55 11 00000-0001",
      waba_id: "waba_001",
      space: whatsapp_phone_numbers(:space_number).space
    )
    assert_not pn.valid?
    assert pn.errors[:space_id].any?
  end

  test "allows multiple records with nil space_id" do
    pn = WhatsappPhoneNumber.new(
      phone_number_id: "another_system_id",
      display_number: "+55 11 00000-0002",
      waba_id: "waba_002",
      space: nil
    )
    assert pn.valid?
  end

  # ── system_bot? ───────────────────────────────────────────────────────────────

  test "system_bot? returns true when space_id is nil" do
    assert whatsapp_phone_numbers(:system_bot).system_bot?
  end

  test "system_bot? returns false when space_id is set" do
    assert_not whatsapp_phone_numbers(:space_number).system_bot?
  end

  # ── system_bot scope ──────────────────────────────────────────────────────────

  test "system_bot scope returns only records with nil space_id" do
    results = WhatsappPhoneNumber.system_bot
    assert results.any?
    assert results.all? { |pn| pn.space_id.nil? }
    assert_not_includes results, whatsapp_phone_numbers(:space_number)
  end
end
