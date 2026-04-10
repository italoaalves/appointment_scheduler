# frozen_string_literal: true

module Backups
  class NightlyDatabaseBackupJob < ApplicationJob
    queue_as :default

    def perform(force: false, triggered_by_user_id: nil)
      result = NightlyDatabaseBackup.call(force:)
      return if result.nil?

      Rails.logger.info(
        "[Backups::NightlyDatabaseBackupJob] remote_key=#{result.remote_key} " \
        "triggered_by_user_id=#{triggered_by_user_id || 'system'}"
      )
    rescue StandardError => e
      Rails.logger.error(
        "[Backups::NightlyDatabaseBackupJob] failed triggered_by_user_id=#{triggered_by_user_id || 'system'} " \
        "#{e.class}: #{e.message}"
      )
      raise
    end
  end
end
