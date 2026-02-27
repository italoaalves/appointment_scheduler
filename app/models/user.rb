class User < ApplicationRecord
  has_one :space_membership, dependent: :destroy, autosave: true
  has_one :space, through: :space_membership

  has_one :user_preference, dependent: :destroy
  has_many :user_permissions, dependent: :destroy
  accepts_nested_attributes_for :user_permissions, allow_destroy: true

  has_many :customers, dependent: :nullify
  has_many :appointments, through: :customers
  has_many :notifications, dependent: :destroy

  has_many :sent_messages, class_name: "Message", foreign_key: :sender_id
  has_many :received_messages, class_name: "Message", foreign_key: :recipient_id

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  enum :system_role, { super_admin: 0 }, prefix: false

  after_save :sync_permissions_from_param
  after_create :ensure_user_preference
  after_commit :create_owner_space, on: :create

  # Virtual attribute: reads/writes through SpaceMembership so that
  # forms, controllers, and seeds that assign user.space_id keep working.
  def space_id
    space_membership&.space_id
  end

  def space_id=(value)
    if value.blank?
      space_membership&.mark_for_destruction
    elsif space_membership
      space_membership.space_id = value
    else
      build_space_membership(space_id: value)
    end
  end

  def permission_names_param
    permission_names
  end

  def permission_names_param=(vals)
    @permission_names_param = Array(vals).reject(&:blank?).map(&:to_s)
  end

  def can?(permission, space: nil)
    PermissionService.can?(user: self, permission: permission, space: space)
  end

  def space_owner?(space = nil)
    target = space || self.space
    target.present? && target.owner_id == id
  end

  def permission_names
    @permission_names_cache ||= user_permissions.pluck(:permission)
  end

  def clear_permission_cache!
    @permission_names_cache = nil
  end

  def sync_permissions_from_param
    return if @permission_names_param.nil?

    SyncUserPermissions.call(self, @permission_names_param)
  end

  private

  def ensure_user_preference
    return if user_preference.present?

    create_user_preference!(locale: I18n.default_locale.to_s)
  end

  def create_owner_space
    CreateOwnerSpace.call(self)
  end
end
