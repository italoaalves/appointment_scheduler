# frozen_string_literal: true

module TurboStreamHelper
  # Returns a turbo_stream action that prepends a flash message
  # into the #flash_messages container.
  def turbo_stream_flash(type:, message:)
    turbo_stream.prepend("flash_messages") do
      render partial: "shared/flash_stream", locals: { type: type, message: message }
    end
  end
end
