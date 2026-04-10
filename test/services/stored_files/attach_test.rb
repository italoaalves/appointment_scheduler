# frozen_string_literal: true

require "test_helper"

module StoredFiles
  class AttachTest < ActiveSupport::TestCase
    setup do
      @user = users(:manager)
      @scope_config = ScopeConfig.new(
        name: "profile_picture",
        adapter: "local",
        allowed_content_types: %w[image/png image/jpeg image/webp],
        max_bytes: 5.megabytes
      )
      @storage = Adapters::Local.new(root: Rails.root.join("tmp/stored_files"))
    end

    test "stores file metadata for the attachable record" do
      prepared = PrepareUpload.call(scope: :profile_picture, upload: image_upload, scope_config: @scope_config).prepared_upload

      result = Attach.call(record: @user, scope: :profile_picture, prepared_upload: prepared, storage: @storage, scope_config: @scope_config)

      assert_predicate result, :success?
      stored_file = @user.reload.profile_picture_file
      assert_equal "profile_picture", stored_file.scope
      assert_equal "local", stored_file.storage_adapter
      assert_equal @user.space, stored_file.space
      assert_equal "image/png", stored_file.content_type
      assert_equal prepared.byte_size, stored_file.byte_size
      assert File.exist?(Rails.root.join("tmp/stored_files", stored_file.storage_path))
    end

    test "replaces an existing file and removes the previous binary" do
      first_upload = PrepareUpload.call(scope: :profile_picture, upload: image_upload(filename: "first.png"), scope_config: @scope_config).prepared_upload
      first_result = Attach.call(record: @user, scope: :profile_picture, prepared_upload: first_upload, storage: @storage, scope_config: @scope_config)
      old_path = first_result.stored_file.storage_path

      second_upload = PrepareUpload.call(scope: :profile_picture, upload: image_upload(filename: "second.png"), scope_config: @scope_config).prepared_upload
      Attach.call(record: @user, scope: :profile_picture, prepared_upload: second_upload, storage: @storage, scope_config: @scope_config)

      refute_equal old_path, @user.reload.profile_picture_file.storage_path
      assert_not File.exist?(Rails.root.join("tmp/stored_files", old_path))
    end
  end
end
