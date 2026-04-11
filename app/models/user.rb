class User < ApplicationRecord
  encrypts :phone_number, deterministic: true
  encrypts :cpf_cnpj
  encrypts :totp_secret

  has_one :space_membership, dependent: :destroy, autosave: true
  has_one :space, through: :space_membership

  has_one :user_preference, dependent: :destroy
  has_many :stored_files, as: :attachable, dependent: :destroy, inverse_of: :attachable
  has_one :profile_picture_file,
          -> { where(scope: StoredFile::PROFILE_PICTURE_SCOPE) },
          as: :attachable,
          class_name: "StoredFile",
          inverse_of: :attachable
  has_many :account_deletion_requests, dependent: :destroy
  has_many :user_identities, dependent: :destroy
  has_many :user_passkeys, dependent: :destroy
  has_many :user_recovery_codes, dependent: :destroy
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
         :recoverable, :rememberable, :validatable, :confirmable, :timeoutable, :omniauthable,
         omniauth_providers: %i[google_oauth2 apple]

  enum :system_role, { super_admin: 0 }, prefix: false

  # Set to true in Users::RegistrationsController to enforce phone presence
  # on the public sign-up form only (not admin or manager-created users).
  attr_accessor :require_phone_number
  attr_accessor :require_legal_acceptance, :accept_terms_of_service, :accept_privacy_policy

  before_validation :normalize_phone_number
  before_validation :capture_legal_acceptance, on: :create
  validates :phone_number, presence: true, if: :require_phone_number
  validates :accept_terms_of_service, acceptance: { accept: "1" }, if: :require_legal_acceptance, allow_nil: false
  validates :accept_privacy_policy, acceptance: { accept: "1" }, if: :require_legal_acceptance, allow_nil: false
  validates :phone_number, uniqueness: { allow_blank: true, message: :cannot_be_verified }
  validate :phone_number_locked_during_trial, if: :phone_number_changed?

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

  def preferred_locale
    LocaleResolver.recipient(self)
  end

  def mfa_enabled?
    mfa_enabled_at.present?
  end

  def mfa_required?
    super_admin? || mfa_enabled?
  end

  def mfa_setup_required?
    super_admin? && !mfa_enabled?
  end

  def passkeys_enabled?
    user_passkeys.exists?
  end

  def totp_enabled?
    totp_secret.present? && totp_enabled_at.present?
  end

  def totp_provisioning_uri(secret: totp_secret)
    return if secret.blank?

    ROTP::TOTP.new(secret, issuer: AppBrand.authenticator_name).provisioning_uri(email)
  end

  def ensure_webauthn_id!
    return webauthn_id if webauthn_id.present?

    update!(webauthn_id: WebAuthn.generate_user_id)
    webauthn_id
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

  def phone_number_locked_during_trial
    return unless persisted?
    return if super_admin?
    return unless space&.subscription&.trialing?

    errors.add(:phone_number, :locked_during_trial)
  end

  def normalize_phone_number
    if phone_number.present?
      self.phone_number = "+#{phone_number.gsub(/\D/, '')}"
    else
      self.phone_number = nil
    end
  end

  def ensure_user_preference
    return if user_preference.present?

    create_user_preference!(locale: I18n.default_locale.to_s)
  end

  def capture_legal_acceptance
    accepted_at = Time.current

    if accept_terms_of_service == "1"
      self.terms_of_service_accepted_at ||= accepted_at
      self.terms_of_service_version ||= Legal::DocumentCatalog.fetch(:terms_of_service).version
    end

    return unless accept_privacy_policy == "1"

    self.privacy_policy_accepted_at ||= accepted_at
    self.privacy_policy_version ||= Legal::DocumentCatalog.fetch(:privacy_policy).version
  end

  def create_owner_space
    CreateOwnerSpace.call(self)
  end
end
