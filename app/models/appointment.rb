class Appointment < ApplicationRecord
  include SpaceScoped

  default_scope { where(discarded_at: nil) }

  SLOT_BLOCKING_STATUSES = %i[pending confirmed rescheduled].freeze

  belongs_to :space
  belongs_to :customer, optional: true

  before_validation :set_duration_from_space, on: :create

  validate :customer_belongs_to_space, if: :customer_id?
  validate :no_double_booking, if: :requires_slot_validation?

  def effective_duration_minutes
    duration_minutes.presence || space&.slot_duration_minutes || 30
  end

  def scheduled_in_past?
    scheduled_at.present? && scheduled_at <= Time.current
  end

  def save(**options, &block)
    super
  rescue ActiveRecord::RecordNotUnique => e
    raise unless e.message.include?("index_appointments_unique_active_slot")

    errors.add(:base, :slot_already_booked)
    false
  end

  enum :status, {
    pending: 0,
    confirmed: 1,
    cancelled: 2,
    rescheduled: 3,
    no_show: 4,
    finished: 5
  }

  private

  def set_duration_from_space
    return if duration_minutes.present?
    return unless space_id.present?

    self.duration_minutes = space.slot_duration_minutes
  end

  def customer_belongs_to_space
    return unless space_id.present? && customer_id.present?

    unless space.customers.exists?(id: customer_id)
      errors.add(:customer_id, :invalid)
    end
  end

  def requires_slot_validation?
    status&.to_sym.in?(SLOT_BLOCKING_STATUSES) && scheduled_at.present?
  end

  def no_double_booking
    return unless space_id.present? && scheduled_at.present?

    acquire_slot_advisory_lock!

    my_end = scheduled_at + effective_duration_minutes.minutes
    conflict_exists = space.appointments
      .where(status: SLOT_BLOCKING_STATUSES)
      .where.not(id: id)
      .where.not(scheduled_at: nil)
      .where("scheduled_at < ? AND (scheduled_at + (COALESCE(duration_minutes, ?) || ' minutes')::interval) > ?",
             my_end, space&.slot_duration_minutes || 30, scheduled_at)
      .exists?

    errors.add(:base, :slot_already_booked) if conflict_exists
  end

  # Serializes concurrent slot checks for the same space+date within a transaction,
  # closing the TOCTOU window between the overlap query and the INSERT/UPDATE.
  def acquire_slot_advisory_lock!
    lock_key = Zlib.crc32("appointment_slot:#{space_id}:#{scheduled_at.to_date}")
    self.class.connection.exec_query(
      "SELECT pg_advisory_xact_lock($1)", "AdvisoryLock", [ lock_key ]
    )
  end
end
