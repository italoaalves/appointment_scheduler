# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Backups
  class RestoreDatabaseBackupTest < ActiveSupport::TestCase
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
        when "aws"
          destination = command[4]
          File.write(destination, "encrypted")
        when "age"
          output_path = command[command.index("-o") + 1]
          File.write(output_path, "decrypted-dump")
        when "pg_restore"
          nil
        end

        [ "", "", FakeStatus.new(true) ]
      end
    end

    test "restores a backup into a target database" do
      runner = FakeRunner.new

      Dir.mktmpdir do |dir|
        age_key_file = File.join(dir, "restore.agekey")
        File.write(age_key_file, "AGE-SECRET-KEY-TEST")

        result = RestoreDatabaseBackup.call(
          configuration: Configuration.new(
            settings: {
              r2_bucket: "anella-db-backups",
              r2_access_key_id: "key",
              r2_secret_access_key: "secret",
              r2_endpoint: "https://example.r2.cloudflarestorage.com",
              aws_cli_bin: "aws",
              age_bin: "age",
              pg_restore_bin: "pg_restore"
            }
          ),
          runner:,
          rails_env: "staging",
          backup_key: "postgres/daily/2026/04/10/appointment_scheduler.dump.age",
          age_key_file:,
          target_database: "appointment_scheduler_restore"
        )

        assert_equal "appointment_scheduler_restore", result.target_database
        assert_equal [ "aws", "age", "pg_restore" ], runner.commands.map { |entry| entry[:command].first }
        assert_equal "appointment_scheduler_restore", runner.commands.last[:command][runner.commands.last[:command].index("--dbname") + 1]
      end
    end

    test "refuses to restore into the current application database by default" do
      error = assert_raises(RestoreDatabaseBackup::GuardrailError) do
        Dir.mktmpdir do |dir|
          age_key_file = File.join(dir, "restore.agekey")
          File.write(age_key_file, "AGE-SECRET-KEY-TEST")

          RestoreDatabaseBackup.call(
            configuration: Configuration.new(
              settings: {
                r2_bucket: "anella-db-backups",
                r2_access_key_id: "key",
                r2_secret_access_key: "secret",
                r2_endpoint: "https://example.r2.cloudflarestorage.com"
              }
            ),
            runner: FakeRunner.new,
            rails_env: "development",
            backup_key: "postgres/daily/2026/04/10/appointment_scheduler.dump.age",
            age_key_file:,
            target_database: ActiveRecord::Base.connection_db_config.configuration_hash[:database]
          )
        end
      end

      assert_match "ALLOW_SAME_DATABASE_RESTORE=yes", error.message
    end

    test "requires explicit confirmation on production hosts" do
      error = assert_raises(RestoreDatabaseBackup::GuardrailError) do
        Dir.mktmpdir do |dir|
          age_key_file = File.join(dir, "restore.agekey")
          File.write(age_key_file, "AGE-SECRET-KEY-TEST")

          RestoreDatabaseBackup.call(
            configuration: Configuration.new(
              settings: {
                r2_bucket: "anella-db-backups",
                r2_access_key_id: "key",
                r2_secret_access_key: "secret",
                r2_endpoint: "https://example.r2.cloudflarestorage.com"
              }
            ),
            runner: FakeRunner.new,
            rails_env: "production",
            backup_key: "postgres/daily/2026/04/10/appointment_scheduler.dump.age",
            age_key_file:,
            target_database: "appointment_scheduler_restore"
          )
        end
      end

      assert_match "ALLOW_PRODUCTION_RESTORE=yes", error.message
      assert_match "RESTORE appointment_scheduler_restore IN PRODUCTION", error.message
    end
  end
end
