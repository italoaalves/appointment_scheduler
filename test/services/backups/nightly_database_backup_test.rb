# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Backups
  class NightlyDatabaseBackupTest < ActiveSupport::TestCase
    class FakeStatus
      def initialize(success)
        @success = success
      end

      def success?
        @success
      end
    end

    class FakeRunner
      attr_reader :commands

      def initialize
        @commands = []
      end

      def capture3(env, *command)
        @commands << { env:, command: }

        case command[0]
        when "pg_dump"
          dump_path = command[command.index("-f") + 1]
          File.write(dump_path, "fake dump")
        when "age"
          output_path = command[command.index("-o") + 1]
          input_path = command.last
          File.write(output_path, "encrypted:#{File.read(input_path)}")
        when "aws"
          nil
        end

        [ "", "", FakeStatus.new(true) ]
      end
    end

    setup do
      @setting = BackupSetting.current
      @now = Time.utc(2026, 4, 10, 2, 30, 0)
    end

    test "creates an encrypted dump, uploads it, and updates the backup setting" do
      runner = FakeRunner.new

      Dir.mktmpdir do |dir|
        configuration = Configuration.new(
          settings: {
            r2_bucket: "anella-db-backups",
            r2_access_key_id: "key",
            r2_secret_access_key: "secret",
            r2_endpoint: "https://example.r2.cloudflarestorage.com",
            r2_region: "auto",
            age_recipient: "age1recipient",
            object_prefix: "postgres/daily",
            local_directory: dir,
            local_retention_count: 7,
            file_basename: "appointment_scheduler",
            pg_dump_bin: "pg_dump",
            age_bin: "age",
            aws_cli_bin: "aws"
          }
        )

        result = NightlyDatabaseBackup.call(
          setting: @setting,
          configuration: configuration,
          runner: runner,
          clock: -> { @now }
        )

        assert_equal "postgres/daily/2026/04/10/appointment_scheduler-20260410T023000Z.dump.age", result.remote_key
        assert_equal BackupSetting::STATUS_SUCCEEDED, @setting.reload.last_status
        assert_equal result.remote_key, @setting.last_remote_key
        assert_equal @now, @setting.last_success_at
        assert File.exist?(result.encrypted_path)
        assert_equal 4, runner.commands.length
        assert_equal [ "pg_dump", "age", "aws", "aws" ], runner.commands.map { |entry| entry[:command].first }
      end
    end

    test "skips scheduled runs when backups are disabled" do
      @setting.update!(enabled: false)
      runner = FakeRunner.new

      NightlyDatabaseBackup.call(
        setting: @setting,
        configuration: Configuration.new(settings: {}),
        runner: runner,
        clock: -> { @now }
      )

      assert_empty runner.commands
      assert_nil @setting.reload.last_status
    end

    test "records failures when required configuration is missing" do
      error = assert_raises(NightlyDatabaseBackup::ConfigurationError) do
        NightlyDatabaseBackup.call(
          setting: @setting,
          configuration: Configuration.new(settings: {}),
          runner: FakeRunner.new,
          clock: -> { @now },
          force: true
        )
      end

      assert_match "Missing backup configuration", error.message
      assert_equal BackupSetting::STATUS_FAILED, @setting.reload.last_status
      assert_match "r2_bucket", @setting.last_error
    end
  end
end
