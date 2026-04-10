# frozen_string_literal: true

module Profiles
  class UpdateSettings
    def self.call(user:, attributes:, password_attributes: nil, profile_picture_upload: nil)
      new(user:, attributes:, password_attributes:, profile_picture_upload:).call
    end

    def initialize(user:, attributes:, password_attributes:, profile_picture_upload:)
      @user = user
      @attributes = attributes
      @password_attributes = password_attributes
      @profile_picture_upload = profile_picture_upload
    end

    def call
      prepared_upload = StoredFiles::PrepareUpload.call(
        scope: StoredFile::PROFILE_PICTURE_SCOPE,
        upload: @profile_picture_upload,
        record: @user
      )
      return false unless prepared_upload.success?

      success = false

      ActiveRecord::Base.transaction do
        saved = if @password_attributes.present?
          @user.update_with_password(@password_attributes)
        else
          @user.update(@attributes)
        end

        raise ActiveRecord::Rollback unless saved

        attach_result = StoredFiles::Attach.call(
          record: @user,
          scope: StoredFile::PROFILE_PICTURE_SCOPE,
          prepared_upload: prepared_upload.prepared_upload
        )
        raise ActiveRecord::Rollback unless attach_result.success?

        success = true
      end

      success
    end
  end
end
