# frozen_string_literal: true

module Spaces
  class UpdateSettings
    def self.call(space:, attributes:, banner_upload: nil)
      new(space:, attributes:, banner_upload:).call
    end

    def initialize(space:, attributes:, banner_upload:)
      @space = space
      @attributes = attributes
      @banner_upload = banner_upload
    end

    def call
      prepared_upload = StoredFiles::PrepareUpload.call(
        scope: StoredFile::SPACE_BANNER_SCOPE,
        upload: @banner_upload,
        record: @space
      )
      return false unless prepared_upload.success?

      success = false

      ActiveRecord::Base.transaction do
        raise ActiveRecord::Rollback unless @space.update(@attributes)

        attach_result = StoredFiles::Attach.call(
          record: @space,
          scope: StoredFile::SPACE_BANNER_SCOPE,
          prepared_upload: prepared_upload.prepared_upload
        )
        raise ActiveRecord::Rollback unless attach_result.success?

        success = true
      end

      success
    end
  end
end
