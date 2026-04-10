# frozen_string_literal: true

module Spaces
  module Space
    class BannersController < Spaces::BaseController
      include RequirePermission

      require_permission :manage_space, only: [ :show, :destroy ]
      before_action :set_space

      def show
        stored_file = @space.banner_file
        return head :not_found if stored_file.blank?

        data = StoredFiles.storage_by_name(stored_file.storage_adapter).download(key: stored_file.storage_path)
        return head :not_found if data.blank?

        send_data data, type: stored_file.content_type, disposition: :inline
      end

      def destroy
        result = StoredFiles::Remove.call(record: @space, scope: StoredFile::SPACE_BANNER_SCOPE)
        flash_type = result.success? ? :notice : :alert
        flash_message = t(result.success? ? "space.settings.edit.banner_removed" : "space.settings.edit.banner_remove_failed")

        redirect_to edit_settings_space_path, flash_type => flash_message, status: :see_other
      end

      private

      def set_space
        @space = current_tenant
        redirect_to root_path, alert: t("space.settings.no_space") unless @space
      end
    end
  end
end
