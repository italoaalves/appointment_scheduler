class User < ApplicationRecord
  belongs_to :space, optional: true

  has_many :clients, dependent: :nullify
  has_many :appointments, through: :clients
  has_many :notifications, dependent: :destroy

  has_many :sent_messages, class_name: "Message", foreign_key: :sender_id
  has_many :received_messages, class_name: "Message", foreign_key: :recipient_id

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, { admin: 0, manager: 1, secretary: 2 }

  after_create :ensure_space_for_manager

  private

  def ensure_space_for_manager
    return unless manager? && space_id.nil?

    created_space = Space.create!(name: name.presence || email)
    update_column(:space_id, created_space.id)
  end
end

