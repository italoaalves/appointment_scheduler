# frozen_string_literal: true

module Spaces
  class NotificationsController < Spaces::BaseController
    before_action :find_notification, only: [ :mark_as_read, :dismiss ]

    # GET /notifications — Turbo Frame only
    def index
      unless turbo_frame_request?
        redirect_to root_path and return
      end

      @notifications = current_user.notifications.recent(10)
      @unread_count  = current_user.notifications.unread.count
    end

    # PATCH /notifications/:id/mark_as_read
    def mark_as_read
      @notification.mark_as_read!

      target = @notification.target_path
      if target
        redirect_to url_for(target)
      else
        redirect_to root_path
      end
    end

    # PATCH /notifications/:id/dismiss
    def dismiss
      @notification.destroy!

      respond_to do |format|
        format.turbo_stream do
          @unread_count = current_user.notifications.unread.count
        end
        format.html { redirect_back fallback_location: root_path }
      end
    end

    # PATCH /notifications/mark_all_as_read
    def mark_all_as_read
      current_user.notifications.unread.update_all(read: true)

      respond_to do |format|
        format.turbo_stream do
          @notifications = current_user.notifications.recent(10)
          @unread_count  = 0
        end
        format.html { redirect_back fallback_location: root_path }
      end
    end

    private

    def find_notification
      @notification = current_user.notifications.find(params[:id])
    end
  end
end
