# frozen_string_literal: true

module Booking
  class SlotUpdatesBroadcaster
    class << self
      include ActionView::RecordIdentifier

      def broadcast_for(space)
        return if space.blank?

        Turbo::StreamsChannel.broadcast_replace_to(
          stream_name(space),
          target: dom_id(space, :booking_slots_sync),
          partial: "booking/slot_sync",
          locals: { space: space, refresh_key: SecureRandom.hex(8) }
        )
      end

      def stream_name(space)
        [ space, :booking_slots ]
      end
    end
  end
end
