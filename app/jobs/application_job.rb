# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  rescue_from StandardError do |error|
    Observability::UnexpectedErrorReporter.report(
      error,
      handled: false,
      source: "application.active_job",
      context: Observability::UnexpectedErrorReporter.job_context(self)
    )
    raise error
  end

  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 10, report: true

  discard_on ActiveJob::DeserializationError, report: true do |job, error|
    Rails.logger.warn("[JOB_DISCARDED] #{job.class.name} (#{job.job_id}): #{error.message}")
  end

  def perform_now
    Rails.error.set_context(**Observability::UnexpectedErrorReporter.job_context(self)) do
      super
    end
  end
end
