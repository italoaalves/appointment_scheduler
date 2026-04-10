# frozen_string_literal: true

require "open3"
require "shellwords"
require "uri"
require "fileutils"

module Backups
  class NightlyDatabaseBackup
    class Error < StandardError; end
    class ConfigurationError < Error; end

    class CommandError < Error
      attr_reader :command, :stderr

      def initialize(command:, stderr:)
        @command = command
        @stderr = stderr
        super("Command failed: #{command}#{": #{stderr}" if stderr.present?}")
      end
    end

    Result = Struct.new(:remote_key, :encrypted_path, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(setting: BackupSetting.current, configuration: Configuration.resolved, runner: Open3, clock: -> { Time.current }, force: false)
      @setting = setting
      @configuration = configuration
      @runner = runner
      @clock = clock
      @force = force
    end

    def call
      return if !@force && !@setting.enabled?

      ensure_configuration!

      started_at = @clock.call
      @setting.mark_started!(at: started_at)

      FileUtils.mkdir_p(@configuration.local_directory)

      timestamp = started_at.utc.strftime("%Y%m%dT%H%M%SZ")
      basename = "#{@configuration.file_basename}-#{timestamp}"
      dump_path = @configuration.local_directory.join("#{basename}.dump")
      encrypted_path = @configuration.local_directory.join("#{basename}.dump.age")
      remote_key = build_remote_key(started_at, basename)

      run_command(database_environment, @configuration.pg_dump_bin, "-Fc", "--no-owner", "--no-privileges", "-f", dump_path.to_s, database_name)
      run_command({}, @configuration.age_bin, "-r", @configuration.age_recipient, "-o", encrypted_path.to_s, dump_path.to_s)
      File.delete(dump_path) if dump_path.exist?

      run_command(
        @configuration.aws_environment,
        @configuration.aws_cli_bin,
        "s3",
        "cp",
        encrypted_path.to_s,
        "s3://#{@configuration.r2_bucket}/#{remote_key}",
        "--endpoint-url",
        @configuration.r2_endpoint,
        "--only-show-errors"
      )
      run_command(
        @configuration.aws_environment,
        @configuration.aws_cli_bin,
        "s3api",
        "head-object",
        "--bucket",
        @configuration.r2_bucket,
        "--key",
        remote_key,
        "--endpoint-url",
        @configuration.r2_endpoint
      )

      prune_local_backups!

      finished_at = @clock.call
      @setting.mark_succeeded!(finished_at:, remote_key:)
      Result.new(remote_key:, encrypted_path: encrypted_path.to_s)
    rescue StandardError => e
      @setting.mark_failed!(finished_at: @clock.call, error: e.message) if @setting.persisted?
      raise
    ensure
      File.delete(dump_path) if defined?(dump_path) && dump_path&.exist?
    end

    private

    def ensure_configuration!
      return if @configuration.ready?

      raise ConfigurationError, "Missing backup configuration: #{@configuration.missing_keys.join(', ')}"
    end

    def build_remote_key(time, basename)
      [
        @configuration.object_prefix,
        time.utc.strftime("%Y"),
        time.utc.strftime("%m"),
        time.utc.strftime("%d"),
        "#{basename}.dump.age"
      ].join("/")
    end

    def prune_local_backups!
      Dir[@configuration.local_directory.join("*.dump").to_s].each { |path| File.delete(path) }

      encrypted_backups = Dir[@configuration.local_directory.join("*.dump.age").to_s]
        .sort_by { |path| File.mtime(path) }

      overflow = encrypted_backups.length - @configuration.local_retention_count
      return if overflow <= 0

      encrypted_backups.first(overflow).each { |path| File.delete(path) }
    end

    def run_command(environment, *command)
      stdout, stderr, status = @runner.capture3(environment.compact, *command)
      return stdout if status.success?

      raise CommandError.new(command: Shellwords.join(command), stderr: stderr.presence || stdout.presence)
    rescue Errno::ENOENT => e
      raise CommandError.new(command: Shellwords.join(command), stderr: e.message)
    end

    def database_environment
      db = database_settings

      {
        "PGHOST" => db[:host],
        "PGPORT" => db[:port]&.to_s,
        "PGUSER" => db[:username],
        "PGPASSWORD" => db[:password]
      }.compact
    end

    def database_name
      database_settings.fetch(:database)
    end

    def database_settings
      @database_settings ||= begin
        config = ActiveRecord::Base.connection_db_config.configuration_hash.symbolize_keys
        parsed = parse_database_url(config[:url].presence || ENV["DATABASE_URL"].presence)

        settings = parsed.merge(
          database: config[:database].presence || parsed[:database],
          host: config[:host].presence || parsed[:host],
          port: config[:port].presence || parsed[:port],
          username: config[:username].presence || config[:user].presence || parsed[:username],
          password: config[:password].presence || parsed[:password]
        )

        raise ConfigurationError, "Database name is not configured for backups" if settings[:database].blank?

        settings
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
