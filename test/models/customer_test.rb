# frozen_string_literal: true

require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "belongs to space" do
    customer = customers(:one)
    assert_equal spaces(:one), customer.space
  end

  test "requires name" do
    customer = Customer.new(space: spaces(:one), name: nil)
    assert_not customer.valid?
    assert_includes customer.errors[:name], I18n.t("errors.messages.blank")
  end

  test "valid with name only" do
    customer = spaces(:one).customers.build(name: "New Customer")
    assert customer.valid?
  end

  test "whatsapp consent is not granted by default" do
    customer = customers(:one)

    assert_not customer.whatsapp_opted_in?
  end

  test "grant_whatsapp_consent records active consent metadata" do
    freeze_time do
      customer = customers(:one)

      customer.grant_whatsapp_consent(source: "staff_entry")

      assert customer.whatsapp_opted_in?
      assert_equal Time.current, customer.whatsapp_opted_in_at
      assert_equal "staff_entry", customer.whatsapp_opt_in_source
    end
  end

  test "revoke_whatsapp_consent marks consent as inactive" do
    customer = customers(:one)
    customer.update!(
      whatsapp_opted_in_at: 2.days.ago,
      whatsapp_opt_in_source: "booking_form"
    )

    freeze_time do
      customer.revoke_whatsapp_consent(source: "staff_entry")

      assert_not customer.whatsapp_opted_in?
      assert_equal Time.current, customer.whatsapp_opted_out_at
      assert_equal "staff_entry", customer.whatsapp_opt_out_source
    end
  end

  test "has many appointments" do
    customer = customers(:one)
    assert customer.appointments.any?
  end

  test "nullifies customer_id on destroy" do
    customer = customers(:one)
    apt = customer.appointments.first
    customer.destroy
    apt.reload
    assert_nil apt.customer_id
  end
end
