# frozen_string_literal: true

class BookingController < ApplicationController
  layout "booking"

  before_action :set_scheduling_link, only: [ :show, :slots, :create ]
  before_action :validate_link_usable, only: [ :show, :slots, :create ]

  def show
    @space = @scheduling_link.space
  end

  def slots
    @space = @scheduling_link.space
    tz = TimezoneResolver.zone(@space)
    today_in_space = Time.current.in_time_zone(tz).to_date
    from = params[:from].present? ? Date.parse(params[:from]) : today_in_space
    to = params[:to].present? ? Date.parse(params[:to]) : from + 13.days
    slots = @space.available_slots(from_date: from, to_date: to, limit: 100)

    render json: slots.map { |s| { value: s.iso8601, label: s.strftime("%a %b %d, %Y at %l:%M %p") } }
  rescue ArgumentError
    render json: []
  end

  def create
    @space = @scheduling_link.space
    customer = find_or_create_customer
    appointment = AppointmentCreator.call(
      space: @space,
      customer: customer,
      attributes: { scheduled_at: params[:scheduled_at] }
    )

    if appointment.save
      @scheduling_link.mark_used!
      redirect_to book_path(token: @scheduling_link.token), notice: t("booking.create.success")
    else
      @space = @scheduling_link.space
      flash.now[:alert] = appointment.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_scheduling_link
    @scheduling_link = SchedulingLink.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    render "booking/invalid", status: :not_found
  end

  def validate_link_usable
    return if @scheduling_link.usable?

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
