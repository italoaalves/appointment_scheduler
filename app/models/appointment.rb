class Appointment < ApplicationRecord
  belongs_to :client, class_name: "User"
  belongs_to :managed_by, class_name: "User", optional: true

  enum :status, {
    requested: 0,
    confirmed: 1,
    denied: 2,
    cancelled: 3,
    rescheduled: 4
  }
end
