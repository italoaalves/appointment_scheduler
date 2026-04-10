# frozen_string_literal: true

module Platform
  class BackupsController < BaseController
    def show
      @backup_setting = BackupSetting.current
      @backup_configuration = Backups::Configuration.resolved
    end

    def enable
      backup_setting = BackupSetting.current
      backup_setting.update!(enabled: true)
      audit_toggle!(enabled: true)

      redirect_to platform_backups_path, notice: t("platform.backups.enable.notice")
    end

    def disable
      backup_setting = BackupSetting.current
      backup_setting.update!(enabled: false)
      audit_toggle!(enabled: false)

      redirect_to platform_backups_path, notice: t("platform.backups.disable.notice")
    end

    def run_now
      backup_configuration = Backups::Configuration.resolved

      unless backup_configuration.ready?
        redirect_to platform_backups_path,
          alert: t("platform.backups.run_now.missing_configuration", keys: backup_configuration.missing_keys.join(", "))
        return
      end

      Backups::NightlyDatabaseBackupJob.perform_later(force: true, triggered_by_user_id: real_current_user.id)
      AuditLogs::EventLogger.call(
        event_type: "operations.backup_run_requested",
        actor: real_current_user,
        request: request,
        metadata: audit_context_metadata.merge(surface: "platform_backups")
      )

      redirect_to platform_backups_path, notice: t("platform.backups.run_now.notice")
    end

    private

    def audit_toggle!(enabled:)
      AuditLogs::EventLogger.call(
        event_type: enabled ? "operations.backups_enabled" : "operations.backups_disabled",
        actor: real_current_user,
        request: request,
        metadata: audit_context_metadata.merge(surface: "platform_backups", enabled:)
      )
    end
  end
end
