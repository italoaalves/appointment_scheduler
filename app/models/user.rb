class User < ApplicationRecord
  has_many :appointments, foreign_key: :client_id
  has_many :managed_appointments, class_name: "Appointment", foreign_key: :managed_by_id
  has_many :notifications, dependent: :destroy

  has_many :sent_messages, class_name: "Message", foreign_key: :sender_id
  has_many :received_messages, class_name: "Message", foreign_key: :recipient_id

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

         enum :role, { client: 0, admin: 1 }
end
