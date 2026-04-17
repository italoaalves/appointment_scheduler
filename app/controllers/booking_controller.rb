# frozen_string_literal: true

class BookingController < ApplicationController
  layout "booking"

  before_action :set_booking_context, only: [ :show, :slots, :create, :thank_you ]
  before_action :validate_booking_usable, only: [ :show, :slots, :create ]

  CALENDAR_VERIFIER = Rails.application.message_verifier(:booking_calendar)

  def show
    @space = @booking_context.space
  end

  def slots
    @space = @booking_context.space
    tz = TimezoneResolver.zone(@space)
    today_in_space = Time.current.in_time_zone(tz).to_date
    from = params[:from].present? ? Date.parse(params[:from]) : today_in_space
    to = params[:to].present? ? Date.parse(params[:to]) : from + 13.days
    slots = @space.available_slots(from_date: from, to_date: to, limit: 100)

    render json: BookingSlotsSerializer.to_json(slots)
  rescue ArgumentError
    render json: []
  end

  def thank_you
    @space = @booking_context.space
    @appointment = Booking::ConfirmationToken.resolve(token: params[:confirmation], booking_context: @booking_context)

    return if @appointment.present?

    redirect_to @booking_context.form_url, alert: t("booking.thank_you.invalid_access")
  end

  def calendar_ics
    appointment_id = CALENDAR_VERIFIER.verified(params[:token])
    appointment = appointment_id.present? ? Appointment.find_by(id: appointment_id) : nil
    unless appointment
      head :not_found
      return
    end
    ics = Booking::CalendarFileGenerator.call(appointment: appointment)
    send_data ics,
              filename: Booking::CalendarFileGenerator.new(appointment: appointment).filename,
              type: "text/calendar",
              disposition: "attachment"
  end

  def create
    @space = @booking_context.space
    scheduled_at = parse_scheduled_at(booking_params[:scheduled_at])
    if scheduled_at.blank?
      flash.now[:alert] = t("booking.invalid_slot")
      return render :show, status: :unprocessable_entity
    end
    unless Spaces::SpacePolicyChecker.slot_requestable?(space: @space, scheduled_at: scheduled_at)
      flash.now[:alert] = t("booking.slot_outside_window")
      return render :show, status: :unprocessable_entity
    end
    customer = find_or_create_customer
    return if performed?

    appointment = Spaces::AppointmentCreator.call(
      space: @space,
      customer: customer,
      attributes: { scheduled_at: scheduled_at }
    )

    if appointment.save
      confirmation_token = Booking::ConfirmationToken.generate(
        appointment: appointment,
        booking_context: @booking_context
      )

      @booking_context.mark_used!
      Notifications::SendNotificationJob.perform_later(
        event:         :appointment_booked,
        appointment_id: appointment.id,
        confirmation_token: confirmation_token
      )
      redirect_to @booking_context.redirect_after_booking(
        appointment: appointment,
        confirmation_token: confirmation_token
      )
    else
      flash.now[:alert] = appointment.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  def confirm
    token = Booking::ConfirmationToken.verify!(params[:confirmation])
    appointment = Appointment.find(token.appointment_id)

    result = Scheduling::Commands::ConfirmAppointment.call(
      space: appointment.space,
      appointment_id: appointment.id,
      actor: Scheduling::Commands::Base::SystemActor.new(label: "email:link"),
      idempotency_key: "email_confirmation:#{token.jti}",
      metadata: { via: "email_link" }
    )

    return redirect_to confirmation_redirect_url(token, params[:confirmation]) if result.ok?

    render_invalid_confirmation
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    render_invalid_confirmation
  end

  private

  def confirmation_redirect_url(token, confirmation)
    case token.context_type
    when "token"
      thank_you_book_url(token: token.context_value, confirmation: confirmation)
    when "slug"
      thank_you_book_by_slug_url(slug: token.context_value, confirmation: confirmation)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def render_invalid_confirmation
    render plain: t("booking.thank_you.invalid_access"), status: :unprocessable_entity
  end

  def set_booking_context
    if params[:slug].present?
      link = PersonalizedSchedulingLink.find_by!(slug: params[:slug])
      @booking_context = BookingContext::PersonalizedBookingContext.new(link)
    else
      link = SchedulingLink.find_by!(token: params[:token])
      @booking_context = BookingContext::TokenBookingContext.new(link)
    end
  rescue ActiveRecord::RecordNotFound
    render "booking/invalid", status: :not_found
  end

  def validate_booking_usable
    return if @booking_context.usable? == false && (render "booking/expired", status: :gone; true)

    space = @booking_context.space
    subscription = space.subscription
    if subscription&.expired?
      render "booking/unavailable", status: :service_unavailable
    end
  end

  def parse_scheduled_at(value)
    return nil if value.blank?

    tz = TimezoneResolver.zone(@space)
    tz.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def booking_params
    params.permit(:customer_name, :customer_email, :customer_phone, :customer_address, :scheduled_at, :whatsapp_opt_in)
  end

  def find_or_create_customer
    bp    = booking_params
    email = bp[:customer_email].to_s.strip.presence
    phone = bp[:customer_phone].to_s.strip.presence

    existing = Spaces::CustomerFinder.find_existing(space: @space, email: email, phone: phone)
    if existing.nil? && !Billing::PlanEnforcer.can?(@space, :create_customer)
      flash.now[:alert] = t("booking.space_at_capacity")
      render :show, status: :unprocessable_entity
      return nil
    end

    Spaces::CustomerFinder.find_or_create(
      space:   @space,
      email:   email,
      name:    bp[:customer_name].to_s.strip.presence,
      phone:   phone,
      address: bp[:customer_address].to_s.strip.presence,
      whatsapp_opt_in: bp[:whatsapp_opt_in],
      consent_source: "booking_form",
      locale: I18n.locale
    )
  rescue ArgumentError
    flash.now[:alert] = t("booking.email_or_phone_required")
    render :show, status: :unprocessable_entity
    nil
  end
end
