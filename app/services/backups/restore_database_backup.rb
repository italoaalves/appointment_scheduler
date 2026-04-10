# frozen_string_literal: true

require "open3"
require "shellwords"
require "tmpdir"
require "uri"

module Backups
  class RestoreDatabaseBackup
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class GuardrailError < Error; end

    Result = Struct.new(:backup_key, :target_database, keyword_init: true)

    INITIALIZER_KEYS = %i[configuration runner rails_env tempdir_factory].freeze

    def self.call(**kwargs)
      initializer_kwargs = kwargs.slice(*INITIALIZER_KEYS)
      call_kwargs = kwargs.except(*INITIALIZER_KEYS)

      new(**initializer_kwargs).call(**call_kwargs)
    end

    def initialize(configuration: Configuration.resolved, runner: Open3, rails_env: Rails.env, tempdir_factory: Dir)
      @configuration = configuration
      @runner = runner
      @rails_env = rails_env.to_s
      @tempdir_factory = tempdir_factory
    end

    def call(backup_key:, age_key_file:, target_database:, allow_same_database: false, allow_production_restore: false, production_confirm: nil)
      ensure_configuration!
      validate_inputs!(backup_key:, age_key_file:, target_database:)
      enforce_guardrails!(
        target_database:,
        allow_same_database:,
        allow_production_restore:,
        production_confirm:
      )

      @tempdir_factory.mktmpdir("backup-restore") do |dir|
        encrypted_path = File.join(dir, File.basename(backup_key))
        decrypted_path = File.join(dir, File.basename(backup_key, ".age"))

        run_command(
          @configuration.aws_environment,
          @configuration.aws_cli_bin,
          "s3",
          "cp",
          "s3://#{@configuration.r2_bucket}/#{backup_key}",
          encrypted_path,
          "--endpoint-url",
          @configuration.r2_endpoint,
          "--only-show-errors"
        )

        run_command(
          {},
          @configuration.age_bin,
          "--decrypt",
          "-i",
          age_key_file,
          "-o",
          decrypted_path,
          encrypted_path
        )

        run_command(
          database_environment(target_database),
          @configuration.pg_restore_bin,
          "--clean",
          "--if-exists",
          "--no-owner",
          "--no-privileges",
          "--dbname",
          target_database,
          decrypted_path
        )
      end

      Result.new(backup_key:, target_database:)
    end

    def production_confirmation_for(target_database)
      "RESTORE #{target_database} IN PRODUCTION"
    end

    private

    def ensure_configuration!
      return if @configuration.ready_for_remote_storage?

      raise ConfigurationError, "Missing backup configuration: #{@configuration.missing_remote_storage_keys.join(', ')}"
    end

    def validate_inputs!(backup_key:, age_key_file:, target_database:)
      raise Error, "BACKUP_KEY is required" if backup_key.blank?
      raise Error, "TARGET_DATABASE is required" if target_database.blank?
      raise Error, "AGE_KEY_FILE is required" if age_key_file.blank?
      raise Error, "AGE_KEY_FILE does not exist: #{age_key_file}" unless File.exist?(age_key_file)
    end

    def enforce_guardrails!(target_database:, allow_same_database:, allow_production_restore:, production_confirm:)
      if target_database == current_database_name && !allow_same_database
        raise GuardrailError,
          "Refusing to restore into the current application database (#{current_database_name}). " \
          "Set ALLOW_SAME_DATABASE_RESTORE=yes only if you are absolutely sure."
      end

      return unless @rails_env == "production"
      return if allow_production_restore && production_confirm == production_confirmation_for(target_database)

      raise GuardrailError,
        "Refusing to run restore on a production host without explicit confirmation. " \
        "Set ALLOW_PRODUCTION_RESTORE=yes and CONFIRM_PRODUCTION_RESTORE='#{production_confirmation_for(target_database)}'."
    end

    def run_command(environment, *command)
      stdout, stderr, status = @runner.capture3(environment.compact, *command)
      return stdout if status.success?

      raise Error, "Command failed: #{Shellwords.join(command)}#{": #{stderr.presence || stdout.presence}" if stderr.present? || stdout.present?}"
    rescue Errno::ENOENT => e
      raise Error, "Command failed: #{Shellwords.join(command)}: #{e.message}"
    end

    def database_environment(target_database)
      settings = database_settings.merge(database: target_database)

      {
        "PGHOST" => settings[:host],
        "PGPORT" => settings[:port]&.to_s,
        "PGUSER" => settings[:username],
        "PGPASSWORD" => settings[:password]
      }.compact
    end

    def current_database_name
      database_settings[:database]
    end

    def database_settings
      @database_settings ||= begin
        config = ActiveRecord::Base.connection_db_config.configuration_hash.symbolize_keys
        parsed = parse_database_url(config[:url].presence || ENV["DATABASE_URL"].presence)

        {
          database: config[:database].presence || parsed[:database],
          host: config[:host].presence || parsed[:host],
          port: config[:port].presence || parsed[:port],
          username: config[:username].presence || config[:user].presence || parsed[:username],
          password: config[:password].presence || parsed[:password]
        }
      end
    end

    def parse_database_url(url)
      return {} if url.blank?

      uri = URI.parse(url)
      {
        database: uri.path.delete_prefix("/"),
        host: uri.host,
        port: uri.port,
        username: uri.user,
        password: uri.password
      }
    rescue URI::InvalidURIError
      {}
    end
  end
end
