class User < ApplicationRecord
  belongs_to :space, optional: true

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
         :recoverable, :rememberable, :validatable

  enum :system_role, { super_admin: 0 }, prefix: false

  after_save :sync_permissions_from_param
  after_create :ensure_user_preference
  after_commit :ensure_space_for_owner, on: :create

  # role: free-text string for display (e.g. "Manager", "Receptionist")

  def permission_names_param
    permission_names
  end

  def permission_names_param=(vals)
    @permission_names_param = Array(vals).reject(&:blank?).map(&:to_s)
  end

  def can?(permission, space: nil)
    PermissionService.can?(user: self, permission: permission, space: space)
  end

  def permission_names
    user_permissions.pluck(:permission)
  end

  def sync_permissions_from_param
    return if @permission_names_param.nil?

    names = @permission_names_param.reject(&:blank?).map(&:to_s) & PermissionService::ALLOWED_PERMISSIONS
    current = permission_names
    (current - names).each { |p| user_permissions.find_by(permission: p)&.destroy }
    (names - current).each { |p| user_permissions.find_or_create_by!(permission: p) }
  end

  private

  def ensure_user_preference
    return if user_preference.present?

    create_user_preference!(locale: I18n.default_locale.to_s)
  end

  def ensure_space_for_owner
    return unless can?(:own_space) && space_id.nil?

    created_space = Space.create!(name: name.presence || email)
    update_column(:space_id, created_space.id)
  end
end
