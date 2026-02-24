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
