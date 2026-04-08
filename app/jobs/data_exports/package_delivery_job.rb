# frozen_string_literal: true

module DataExports
  class PackageDeliveryJob < ApplicationJob
    discard_on ActiveRecord::RecordNotFound

    def perform(user_id)
      user = User.find(user_id)
      DataExports::PackageMailer.export_ready(user_id:).deliver_now
      AuditLogs::EventLogger.call(
        event_type: "privacy.export_delivered",
        actor: user,
        space: user.space,
        subject: user,
        metadata: { source: "email_delivery" }
      )
    end
  end
end
