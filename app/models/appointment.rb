class Appointment < ApplicationRecord
  belongs_to :user

  enum :status, {
    requested: 0,
    confirmed: 1,
    denied: 2,
    cancelled: 3,
    rescheduled: 4
  }
end
