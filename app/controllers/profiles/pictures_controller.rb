# frozen_string_literal: true

module Profiles
  class PicturesController < ApplicationController
    before_action :authenticate_user!

    def show
      stored_file = current_user.profile_picture_file
      return head :not_found if stored_file.blank?

      data = StoredFiles.storage_by_name(stored_file.storage_adapter).download(key: stored_file.storage_path)
      return head :not_found if data.blank?

      send_data data, type: stored_file.content_type, disposition: :inline
    end

    def destroy
      result = StoredFiles::Remove.call(record: current_user, scope: StoredFile::PROFILE_PICTURE_SCOPE)
      flash_type = result.success? ? :notice : :alert
      flash_message = t(result.success? ? "profiles.edit.profile_picture_removed" : "profiles.edit.profile_picture_remove_failed")

      redirect_to edit_profile_path, flash_type => flash_message, status: :see_other
    end
  end
end
