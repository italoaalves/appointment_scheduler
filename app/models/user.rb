class User < ApplicationRecord
  belongs_to :space, optional: true

  has_one :user_preference, dependent: :destroy

  has_many :customers, dependent: :nullify
  has_many :appointments, through: :customers
  has_many :notifications, dependent: :destroy

  has_many :sent_messages, class_name: "Message", foreign_key: :sender_id
  has_many :received_messages, class_name: "Message", foreign_key: :recipient_id

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, { manager: 0, secretary: 1 }
  enum :system_role, { super_admin: 0 }, prefix: false

  after_create :ensure_space_for_manager
  after_create :ensure_user_preference

  private

  def ensure_user_preference
    return if user_preference.present?

    create_user_preference!(locale: I18n.default_locale.to_s)
  end

  def ensure_space_for_manager
    return unless manager? && space_id.nil?

    created_space = Space.create!(name: name.presence || email)
    update_column(:space_id, created_space.id)
  end
end
