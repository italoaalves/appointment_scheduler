# frozen_string_literal: true

require "test_helper"

class ClientTest < ActiveSupport::TestCase
  test "belongs to space" do
    client = clients(:one)
    assert_equal spaces(:one), client.space
  end

  test "requires name" do
    client = Client.new(space: spaces(:one), name: nil)
    assert_not client.valid?
    assert_includes client.errors[:name], "can't be blank"
  end

  test "valid with name only" do
    client = spaces(:one).clients.build(name: "New Client")
    assert client.valid?
  end

  test "has many appointments" do
    client = clients(:one)
    assert client.appointments.any?
  end

  test "nullifies client_id on destroy" do
    client = clients(:one)
    apt = client.appointments.first
    client.destroy
    apt.reload
    assert_nil apt.client_id
  end
end
