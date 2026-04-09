# frozen_string_literal: true

require "test_helper"

class Booking::SlotUpdatesBroadcasterTest < ActiveSupport::TestCase
  include ActionView::RecordIdentifier

  test "broadcasts a slot sync replacement for the booking page" do
    space = spaces(:one)
    args = nil
    kwargs = nil

    Turbo::StreamsChannel.stub(:broadcast_replace_to, ->(*broadcast_args, **broadcast_kwargs) {
      args = broadcast_args
      kwargs = broadcast_kwargs
    }) do
      Booking::SlotUpdatesBroadcaster.broadcast_for(space)
    end

    assert_equal [ space, :booking_slots ], args.first
    assert_equal dom_id(space, :booking_slots_sync), kwargs[:target]
    assert_equal "booking/slot_sync", kwargs[:partial]
    assert_equal space, kwargs.dig(:locals, :space)
    assert kwargs.dig(:locals, :refresh_key).present?
  end
end
