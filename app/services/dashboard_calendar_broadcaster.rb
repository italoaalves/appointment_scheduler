# frozen_string_literal: true

class DashboardCalendarBroadcaster
  class << self
    include ActionView::RecordIdentifier

    def broadcast_for(space:)
      return if space.blank?

      Turbo::StreamsChannel.broadcast_replace_to(
        stream_name(space),
        target: dom_id(space, :dashboard_calendar),
        partial: "dashboard/calendar_sync",
        locals: { space: space }
      )
    end

    def stream_name(space)
      [ space, :dashboard_calendar ]
    end
  end
end
