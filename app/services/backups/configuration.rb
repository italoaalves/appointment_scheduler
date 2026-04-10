# frozen_string_literal: true

module Backups
  class Configuration
    REMOTE_STORAGE_KEYS = %i[
      r2_bucket
      r2_access_key_id
      r2_secret_access_key
      r2_endpoint
    ].freeze

    ENCRYPTION_KEYS = %i[
      age_recipient
    ].freeze

    REQUIRED_KEYS = (REMOTE_STORAGE_KEYS + ENCRYPTION_KEYS).freeze

    attr_reader :settings

    def self.resolved(env: ENV, credentials: Rails.application.credentials)
      backup_credentials = credentials.respond_to?(:dig) ? credentials.dig(:backups) : {}
      backup_credentials = backup_credentials.to_h.deep_symbolize_keys if backup_credentials.respond_to?(:to_h)
      backup_credentials ||= {}

      endpoint = env["BACKUP_R2_ENDPOINT"].presence ||
        backup_credentials[:r2_endpoint].presence ||
        build_r2_endpoint(env["BACKUP_R2_ACCOUNT_ID"].presence || backup_credentials[:r2_account_id].presence)

      new(
        settings: {
          r2_bucket: env["BACKUP_R2_BUCKET"].presence || backup_credentials[:r2_bucket].presence,
          r2_access_key_id: env["BACKUP_R2_ACCESS_KEY_ID"].presence || backup_credentials[:r2_access_key_id].presence,
          r2_secret_access_key: env["BACKUP_R2_SECRET_ACCESS_KEY"].presence || backup_credentials[:r2_secret_access_key].presence,
          r2_endpoint: endpoint,
          r2_region: env["BACKUP_R2_REGION"].presence || backup_credentials[:r2_region].presence || "auto",
          age_recipient: env["BACKUP_AGE_RECIPIENT"].presence || backup_credentials[:age_recipient].presence,
          object_prefix: env["BACKUP_OBJECT_PREFIX"].presence || backup_credentials[:object_prefix].presence || "postgres/daily",
          local_directory: env["BACKUP_LOCAL_DIRECTORY"].presence || backup_credentials[:local_directory].presence || Rails.root.join("storage/backups").to_s,
          local_retention_count: integer_value(
            env["BACKUP_LOCAL_RETENTION_COUNT"].presence || backup_credentials[:local_retention_count],
            default: 7
          ),
          file_basename: env["BACKUP_FILE_BASENAME"].presence || backup_credentials[:file_basename].presence || "appointment_scheduler",
          pg_dump_bin: env["BACKUP_PG_DUMP_BIN"].presence || backup_credentials[:pg_dump_bin].presence || "pg_dump",
          pg_restore_bin: env["BACKUP_PG_RESTORE_BIN"].presence || backup_credentials[:pg_restore_bin].presence || "pg_restore",
          age_bin: env["BACKUP_AGE_BIN"].presence || backup_credentials[:age_bin].presence || "age",
          aws_cli_bin: env["BACKUP_AWS_CLI_BIN"].presence || backup_credentials[:aws_cli_bin].presence || "aws"
        }
      )
    end

    def self.build_r2_endpoint(account_id)
      return if account_id.blank?

      "https://#{account_id}.r2.cloudflarestorage.com"
    end

    def self.integer_value(value, default:)
      Integer(value || default)
    rescue ArgumentError, TypeError
      default
    end

    def initialize(settings:)
      @settings = settings.deep_symbolize_keys
    end

    def ready?
      missing_keys.empty?
    end

    def missing_keys
      REQUIRED_KEYS.select { |key| settings[key].blank? }
    end

    def ready_for_remote_storage?
      missing_remote_storage_keys.empty?
    end

    def missing_remote_storage_keys
      REMOTE_STORAGE_KEYS.select { |key| settings[key].blank? }
    end

    def aws_environment
      {
        "AWS_ACCESS_KEY_ID" => settings[:r2_access_key_id],
        "AWS_SECRET_ACCESS_KEY" => settings[:r2_secret_access_key],
        "AWS_DEFAULT_REGION" => settings[:r2_region]
      }.compact
    end

    REQUIRED_KEYS.each do |key|
      define_method(key) { settings[key] }
    end

    def object_prefix
      settings[:object_prefix]
    end

    def local_directory
      Pathname.new(settings[:local_directory])
    end

    def local_retention_count
      settings[:local_retention_count]
    end

    def file_basename
      settings[:file_basename]
    end

    def pg_dump_bin
      settings[:pg_dump_bin]
    end

    def age_bin
      settings[:age_bin]
    end

    def pg_restore_bin
      settings[:pg_restore_bin]
    end

    def aws_cli_bin
      settings[:aws_cli_bin]
    end
  end
end
