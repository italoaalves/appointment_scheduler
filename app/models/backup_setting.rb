# frozen_string_literal: true

class BackupSetting < ApplicationRecord
  STATUS_SUCCEEDED = "succeeded"
  STATUS_FAILED = "failed"
  STATUS_RUNNING = "running"

  validates :last_status, inclusion: { in: [ STATUS_SUCCEEDED, STATUS_FAILED, STATUS_RUNNING ] }, allow_blank: true

  def self.current
    order(:id).first_or_create!
  end

  def mark_started!(at: Time.current)
    update!(
      last_status: STATUS_RUNNING,
      last_run_started_at: at,
      last_run_finished_at: nil,
      last_error: nil
    )
  end

  def mark_succeeded!(finished_at:, remote_key:)
    update!(
      last_status: STATUS_SUCCEEDED,
      last_run_finished_at: finished_at,
      last_success_at: finished_at,
      last_remote_key: remote_key,
      last_error: nil
    )
  end

  def mark_failed!(finished_at:, error:)
    update!(
      last_status: STATUS_FAILED,
      last_run_finished_at: finished_at,
      last_failure_at: finished_at,
      last_error: error.to_s.truncate(1_000)
    )
  end
end
