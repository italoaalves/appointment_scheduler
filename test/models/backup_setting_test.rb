# frozen_string_literal: true

require "test_helper"

class BackupSettingTest < ActiveSupport::TestCase
  setup do
    BackupSetting.delete_all
  end

  test "current returns a singleton record" do
    setting = BackupSetting.current

    assert setting.persisted?
    assert_equal setting, BackupSetting.current
    assert_equal 1, BackupSetting.count
  end

  test "mark_succeeded stores the last successful backup metadata" do
    setting = BackupSetting.current
    finished_at = Time.current.change(usec: 0)

    setting.mark_succeeded!(finished_at:, remote_key: "postgres/daily/2026/04/10/backup.dump.age")

    assert_equal BackupSetting::STATUS_SUCCEEDED, setting.reload.last_status
    assert_equal finished_at, setting.last_success_at
    assert_equal "postgres/daily/2026/04/10/backup.dump.age", setting.last_remote_key
    assert_nil setting.last_error
  end
end
