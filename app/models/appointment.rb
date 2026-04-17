class Appointment < ApplicationRecord
  include SpaceScoped

  default_scope { where(discarded_at: nil) }

  SLOT_BLOCKING_STATUSES = %i[pending confirmed rescheduled].freeze
  CONFIRMATION_TRANSITIONS = {
    not_applicable: [ :not_applicable, :awaiting_customer ],
    awaiting_customer: [
      :not_applicable,
      :confirmed_by_customer,
      :declined_by_customer,
      :rescheduled_by_customer,
      :escalated_to_human
    ],
    confirmed_by_customer: [ :not_applicable ],
    declined_by_customer: [ :not_applicable ],
    rescheduled_by_customer: [ :not_applicable ],
    escalated_to_human: [ :not_applicable ]
  }.freeze

  belongs_to :space
  belongs_to :customer, optional: true

  before_validation :set_duration_from_space, on: :create
  after_commit :broadcast_booking_slot_updates
  after_commit :broadcast_dashboard_update, on: :create
  after_commit :broadcast_dashboard_update_if_calendar_changed, on: :update
  after_commit :broadcast_dashboard_update, on: :destroy

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

  # Valid transitions:
  # not_applicable -> awaiting_customer
  # awaiting_customer -> confirmed_by_customer | declined_by_customer |
  #                      rescheduled_by_customer | escalated_to_human
  # any state -> not_applicable
  enum :confirmation_state, {
    not_applicable: 0,
    awaiting_customer: 1,
    confirmed_by_customer: 2,
    declined_by_customer: 3,
    rescheduled_by_customer: 4,
    escalated_to_human: 5
  }, prefix: :confirmation

  def can_transition_confirmation_to?(new_state)
    new_state = new_state.to_s
    return false unless self.class.confirmation_states.key?(new_state)

    CONFIRMATION_TRANSITIONS.fetch(confirmation_state.to_sym, []).include?(new_state.to_sym)
  end

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
    self.class.execute_void_query(
      "SELECT pg_advisory_xact_lock($1)", "AdvisoryLock", [ lock_key ]
    )
  end

  def broadcast_booking_slot_updates
    Booking::SlotUpdatesBroadcaster.broadcast_for(space)
  end

  def broadcast_dashboard_update
    return unless space_id.present? && id.present?

    DashboardCalendarBroadcaster.broadcast_for(space: space || Space.find_by(id: space_id))
  end

  def broadcast_dashboard_update_if_calendar_changed
    return unless saved_change_to_status? || saved_change_to_scheduled_at?

    broadcast_dashboard_update
  end
end
