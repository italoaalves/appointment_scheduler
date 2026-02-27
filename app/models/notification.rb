# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true

  validates :title,      presence: true
  validates :body,       presence: true
  validates :event_type, presence: true

  scope :unread,  -> { where(read: false) }
  scope :ordered, -> { order(created_at: :desc) }
  scope :recent,  ->(n = 10) { ordered.limit(n) }

  def mark_as_read!
    update!(read: true) unless read?
  end

  # Returns a hash the controller can pass to url_for to navigate to the
  # related record. Keeps route helpers out of the model.
  def target_path
    case notifiable_type
    when "Appointment"
      { controller: "spaces/appointments", action: "show", id: notifiable_id }
    when "Billing::Subscription"
      { controller: "spaces/billing", action: "show" }
    when "Billing::MessageCredit"
      { controller: "spaces/credits", action: "show" }
    end
  end
end
