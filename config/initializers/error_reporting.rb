# frozen_string_literal: true

require Rails.root.join("lib/observability/error_log_subscriber")
require Rails.root.join("lib/observability/unexpected_error_reporter")

Rails.error.add_middleware(lambda do |_error, context:, handled:, severity:, source:|
  Observability::UnexpectedErrorReporter.decorate_context(context)
end)

Rails.error.subscribe(Observability::ErrorLogSubscriber.new)
