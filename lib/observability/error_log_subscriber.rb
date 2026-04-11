# frozen_string_literal: true

module Observability
  class ErrorLogSubscriber
    def report(error, handled:, severity:, context:, source:)
      payload = Observability::UnexpectedErrorReporter.incident_payload(
        error,
        handled: handled,
        severity: severity,
        source: source,
        context: context
      )

      Rails.logger.public_send(log_level_for(severity), payload.to_json)
    rescue StandardError => subscriber_error
      Rails.logger.error(
        {
          event: "unexpected_error_subscriber_failure",
          exception_class: subscriber_error.class.name,
          message: subscriber_error.message
        }.to_json
      )
    end

    private

    def log_level_for(severity)
      case severity
      when :info then :info
      when :warning then :warn
      else :error
      end
    end
  end
end
