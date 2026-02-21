class Message < ApplicationRecord
  belongs_to :sender, class_name: "User"
  belongs_to :recipient, class_name: "User"
  belongs_to :messageable, polymorphic: true, optional: true

  enum channel: { internal: 0, whatsapp: 1, email: 2, sms: 3 }
  enum status: { pending: 0, sent: 1, delivered: 2, failed: 3 }
end
