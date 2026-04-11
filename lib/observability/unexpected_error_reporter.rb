# frozen_string_literal: true

require "digest"

module Observability
  module UnexpectedErrorReporter
    MAX_BACKTRACE_LINES = 20

    module_function

    def report(error, handled:, severity: handled ? :warning : :error, source:, context: {})
      Rails.error.report(error, handled:, severity:, source:, context:)
    end

    def controller_context(controller)
      {
        request_id: controller.request.request_id,
        user_id: current_user_id(controller),
        space_id: current_space_id(controller),
        controller: controller.controller_path,
        action: controller.action_name,
        method: controller.request.request_method,
        path: controller.request.path,
        format: controller.request.format&.symbol,
        params: Observability::FilteredParams.call(controller.params)
      }.compact
    end

    def job_context(job)
      {
        job_class: job.class.name,
        job_id: job.job_id,
        queue_name: job.queue_name,
        priority: job.priority,
        executions: job.executions,
        arguments: Observability::FilteredParams.filter(job.arguments)
      }.compact
    end

    def decorate_context(context)
      filtered_context = Observability::FilteredParams.filter(context || {}) || {}
      RuntimeContext.log_payload.merge(filtered_context)
    end

    def incident_payload(error, handled:, severity:, source:, context:)
      {
        event: "unexpected_error",
        handled: handled,
        severity: severity,
        source: source,
        fingerprint: fingerprint(error, source:),
        exception_class: error.class.name,
        message: error.message.to_s,
        backtrace: Array(error.backtrace).first(MAX_BACKTRACE_LINES),
        context: context
      }
    end

    def fingerprint(error, source:)
      Digest::SHA256.hexdigest([ source, error.class.name, primary_backtrace_frame(error) ].join("|"))
    end

    def primary_backtrace_frame(error)
      Array(error.backtrace).find { |line| line.start_with?(Rails.root.to_s) } || Array(error.backtrace).first.to_s
    end

    def current_user_id(controller)
      return unless controller.respond_to?(:current_user, true)

      controller.send(:current_user)&.id
    end

    def current_space_id(controller)
      if controller.respond_to?(:current_tenant, true)
        return controller.send(:current_tenant)&.id
      end

      current_user = controller.respond_to?(:current_user, true) ? controller.send(:current_user) : nil
      current_user&.space_id if current_user.respond_to?(:space_id)
    end
  end
end
