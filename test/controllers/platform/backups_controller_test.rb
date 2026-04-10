# frozen_string_literal: true

require "test_helper"

module Platform
  class BackupsControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      @admin = users(:admin)
      @manager = users(:manager)
      BackupSetting.delete_all
      clear_enqueued_jobs
    end

    test "unauthenticated users are redirected to login" do
      get platform_backups_path

      assert_redirected_to new_user_session_path
    end

    test "non-admin users cannot access backups page" do
      sign_in @manager
      get platform_backups_path

      assert_redirected_to root_path
    end

    test "admin can view the backups page" do
      sign_in @admin

      get platform_backups_path

      assert_response :success
      assert_select "h1", text: I18n.t("platform.backups.show.title")
    end

    test "admin can disable nightly backups" do
      sign_in @admin

      assert_difference "AuditLog.count", 1 do
        patch platform_disable_backups_path
      end

      assert_redirected_to platform_backups_path
      assert_equal false, BackupSetting.current.enabled?
      assert_equal "operations.backups_disabled", AuditLog.order(:id).last.event_type
    end

    test "admin can enable nightly backups" do
      BackupSetting.current.update!(enabled: false)
      sign_in @admin

      assert_difference "AuditLog.count", 1 do
        patch platform_enable_backups_path
      end

      assert_redirected_to platform_backups_path
      assert BackupSetting.current.enabled?
      assert_equal "operations.backups_enabled", AuditLog.order(:id).last.event_type
    end

    test "run now enqueues a forced backup job when configuration is ready" do
      sign_in @admin

      Backups::Configuration.stub(:resolved, Backups::Configuration.new(
        settings: {
          r2_bucket: "bucket",
          r2_access_key_id: "key",
          r2_secret_access_key: "secret",
          r2_endpoint: "https://example.r2.cloudflarestorage.com",
          age_recipient: "age1recipient",
          local_directory: Rails.root.join("tmp/test-backups").to_s
        }
      )) do
        assert_difference "AuditLog.count", 1 do
          assert_enqueued_with(job: Backups::NightlyDatabaseBackupJob, args: [ { force: true, triggered_by_user_id: @admin.id } ]) do
            post platform_run_now_backups_path
          end
        end
      end

      assert_redirected_to platform_backups_path
      assert_equal "operations.backup_run_requested", AuditLog.order(:id).last.event_type
    end

    test "run now refuses to enqueue when configuration is missing" do
      sign_in @admin

      Backups::Configuration.stub(:resolved, Backups::Configuration.new(settings: {})) do
        assert_no_enqueued_jobs only: Backups::NightlyDatabaseBackupJob do
          post platform_run_now_backups_path
        end
      end

      assert_redirected_to platform_backups_path
      assert_match "r2_bucket", flash[:alert]
    end
  end
end
