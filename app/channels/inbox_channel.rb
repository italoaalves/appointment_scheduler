# frozen_string_literal: true

class InboxChannel < ApplicationCable::Channel
  def subscribed
    stream_from "space_#{current_space.id}_inbox"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
