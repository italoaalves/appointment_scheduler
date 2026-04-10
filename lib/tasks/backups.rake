# frozen_string_literal: true

namespace :backups do
  desc "Run an encrypted database backup immediately"
  task create: :environment do
    result = Backups::NightlyDatabaseBackup.call(force: true)

    if result
      puts "Backup uploaded to R2:"
      puts "  #{result.remote_key}"
    else
      puts "Backup skipped because backups are disabled."
    end
  end

  desc "List remote backups in R2. Optional: PREFIX=postgres/daily/2026/04"
  task list: :environment do
    entries = Backups::RemoteInventory.call(prefix: ENV["PREFIX"])

    if entries.empty?
      puts "No backups found."
      next
    end

    entries.each do |entry|
      puts format("%-28s %10s  %s", entry.last_modified || "-", entry.size || "-", entry.key)
    end
  end

  desc "Restore a backup into a target database. Required: BACKUP_KEY=... AGE_KEY_FILE=... TARGET_DATABASE=..."
  task restore: :environment do
    result = Backups::RestoreDatabaseBackup.call(
      backup_key: ENV["BACKUP_KEY"],
      age_key_file: ENV["AGE_KEY_FILE"],
      target_database: ENV["TARGET_DATABASE"],
      allow_same_database: ActiveModel::Type::Boolean.new.cast(ENV["ALLOW_SAME_DATABASE_RESTORE"]),
      allow_production_restore: ActiveModel::Type::Boolean.new.cast(ENV["ALLOW_PRODUCTION_RESTORE"]),
      production_confirm: ENV["CONFIRM_PRODUCTION_RESTORE"]
    )

    puts "Backup restored successfully:"
    puts "  backup: #{result.backup_key}"
    puts "  target database: #{result.target_database}"
  rescue Backups::RestoreDatabaseBackup::GuardrailError,
         Backups::RestoreDatabaseBackup::ConfigurationError,
         Backups::RestoreDatabaseBackup::Error,
         Backups::RemoteInventory::ConfigurationError,
         Backups::RemoteInventory::Error,
         Backups::NightlyDatabaseBackup::ConfigurationError,
         Backups::NightlyDatabaseBackup::Error => e
    abort e.message
  end
end
