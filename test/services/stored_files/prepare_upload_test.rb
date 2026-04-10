# frozen_string_literal: true

require "test_helper"

module StoredFiles
  class PrepareUploadTest < ActiveSupport::TestCase
    setup do
      @scope_config = ScopeConfig.new(
        name: "profile_picture",
        adapter: "local",
        allowed_content_types: %w[image/png image/jpeg image/webp],
        max_bytes: 5.megabytes
      )
    end

    test "returns prepared metadata for an allowed image upload" do
      result = PrepareUpload.call(scope: :profile_picture, upload: image_upload, scope_config: @scope_config)

      assert_predicate result, :success?
      assert_equal "image.png", result.prepared_upload.original_filename
      assert_equal "image/png", result.prepared_upload.content_type
      assert_operator result.prepared_upload.byte_size, :>, 0
      assert_equal ".png", result.prepared_upload.extension
      assert result.prepared_upload.checksum.present?
    end

    test "rejects uploads with disallowed content types" do
      record = users(:manager)

      result = PrepareUpload.call(scope: :profile_picture, upload: text_upload, record:, scope_config: @scope_config)

      assert_not_predicate result, :success?
      assert_includes record.errors.full_messages, I18n.t("stored_files.errors.invalid_content_type", label: I18n.t("stored_files.scopes.profile_picture"))
    end

    test "rejects uploads larger than the configured limit" do
      record = users(:manager)
      tiny_limit = @scope_config.dup
      tiny_limit.max_bytes = 1

      result = PrepareUpload.call(scope: :profile_picture, upload: image_upload, record:, scope_config: tiny_limit)

      assert_not_predicate result, :success?
      assert_includes record.errors.full_messages, I18n.t("stored_files.errors.too_large", label: I18n.t("stored_files.scopes.profile_picture"), max_size: "1 Byte")
    end
  end
end
