# frozen_string_literal: true

require "test_helper"

module Backups
  class NightlyDatabaseBackupJobTest < ActiveJob::TestCase
    test "delegates to the backup service" do
      result = NightlyDatabaseBackup::Result.new(remote_key: "postgres/daily/test.dump.age", encrypted_path: "/tmp/test.dump.age")

      NightlyDatabaseBackup.stub(:call, result) do
        returned = NightlyDatabaseBackupJob.perform_now(force: true, triggered_by_user_id: users(:admin).id)

        assert_equal true, returned
      end
    end

    test "allows skipped service runs without raising" do
      NightlyDatabaseBackup.stub(:call, nil) do
        returned = NightlyDatabaseBackupJob.perform_now

        assert_nil returned
      end
    end
  end
end
