# frozen_string_literal: true

class BookingController < ApplicationController
  layout "booking"

  before_action :set_booking_context, only: [ :show, :slots, :create, :thank_you ]
  before_action :validate_booking_usable, only: [ :show, :slots, :create ]

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
  end

  def create
    @space = @booking_context.space
    customer = find_or_create_customer
    appointment = AppointmentCreator.call(
      space: @space,
      customer: customer,
      attributes: { scheduled_at: params[:scheduled_at] }
    )

    if appointment.save
      @booking_context.mark_used!
      redirect_to @booking_context.redirect_after_booking
    else
      @space = @booking_context.space
      flash.now[:alert] = appointment.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  private

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
    return if @booking_context.usable?

    render "booking/expired", status: :gone
  end

  def find_or_create_customer
    CustomerFinder.find_or_create(
      space: @space,
      email: params[:customer_email].to_s.strip.presence,
      name: params[:customer_name].to_s.strip.presence,
      phone: params[:customer_phone].to_s.strip.presence,
      address: params[:customer_address].to_s.strip.presence
    )
  end
end
