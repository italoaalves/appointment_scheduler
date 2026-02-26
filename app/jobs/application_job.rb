# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 10

  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.warn("[JOB_DISCARDED] #{job.class.name} (#{job.job_id}): #{error.message}")
  end
end
