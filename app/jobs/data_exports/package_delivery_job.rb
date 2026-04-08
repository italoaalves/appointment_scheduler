# frozen_string_literal: true

module DataExports
  class PackageDeliveryJob < ApplicationJob
    discard_on ActiveRecord::RecordNotFound

    def perform(user_id)
      DataExports::PackageMailer.export_ready(user_id:).deliver_now
    end
  end
end
