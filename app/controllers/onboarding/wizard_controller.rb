# frozen_string_literal: true

module Onboarding
  class WizardController < ApplicationController
    BRAZILIAN_TIMEZONES = %w[
      America/Sao_Paulo America/Manaus America/Belem America/Recife
      America/Bahia America/Fortaleza America/Cuiaba America/Porto_Velho
      America/Rio_Branco
    ].freeze

    DURATION_OPTIONS = [ 15, 30, 45, 60, 90, 120 ].freeze
    layout "onboarding"
    before_action :authenticate_user!
    before_action :ensure_space_owner!
    before_action :ensure_not_complete!, only: [ :show ]

    def show
      @step = [ current_tenant.onboarding_step + 1, 3 ].min
      if @step == 2
        ensure_availability_schedule
        @brazilian_timezones = BRAZILIAN_TIMEZONES
        @duration_options = DURATION_OPTIONS
      end
      prepare_step3_resources if @step == 3
      render "onboarding/step#{@step}"
    end

    def update_step1
      if current_tenant.update(step1_params)
        current_user.update(phone_number: step1_params[:phone]) if step1_params[:phone].present?
        current_tenant.update_column(:onboarding_step, 1)
        redirect_to onboarding_wizard_path
      else
        @step = 1
        render "onboarding/step1", status: :unprocessable_entity
      end
    end

    def update_step2
      current_tenant.update!(timezone: step2_timezone, slot_duration_minutes: step2_duration)
      ensure_availability_schedule
      current_tenant.availability_schedule&.update!(timezone: step2_timezone)
      sync_availability_windows(step2_days_params)
      current_tenant.update_column(:onboarding_step, 2)
      redirect_to onboarding_wizard_path
    end

    def update_step3
      current_tenant.update!(onboarding_step: 3, completed_onboarding_at: Time.current)
      redirect_to root_path, notice: t("onboarding.step3.completed_notice")
    end

    def skip
      current_tenant.update!(completed_onboarding_at: Time.current)
      redirect_to root_path
    end

    private

    def ensure_space_owner!
      return if current_user.space_owner?

      redirect_to root_path, alert: t("onboarding.owner_only")
    end

    def ensure_not_complete!
      return unless current_tenant.onboarding_complete?

      redirect_to root_path
    end

    def step1_params
      params.require(:space).permit(:name, :business_type, :phone)
    end

    def step2_timezone
      params[:timezone].presence || current_tenant.timezone
    end

    def step2_duration
      (params[:slot_duration_minutes].presence || current_tenant.slot_duration_minutes).to_i
    end

    def step2_days_params
      permitted = (0..6).map(&:to_s).index_with { [ :enabled, :opens_at, :closes_at ] }
      params.permit(days: permitted).fetch(:days, {}).to_h
    end

    def prepare_step3_resources
      @scheduling_link = current_tenant.scheduling_links.find_or_create_by!(link_type: :permanent) do |link|
        link.name = I18n.t("onboarding.step3.default_link_name")
      end

      unless current_tenant.personalized_scheduling_link.present?
        slug = Onboarding::SlugGenerator.call(current_tenant.name)
        current_tenant.create_personalized_scheduling_link!(slug: slug)
      end

      current_tenant.availability_schedule&.touch # refresh business_hours cache
      @personalized_link = current_tenant.personalized_scheduling_link.reload
      @booking_url = book_by_slug_url(slug: @personalized_link.slug)
    end

    def ensure_availability_schedule
      return if current_tenant.availability_schedule.present?

      AvailabilitySchedule.create!(schedulable: current_tenant, timezone: current_tenant.timezone)
    end

    def sync_availability_windows(days)
      return unless days.is_a?(Hash)

      schedule = current_tenant.availability_schedule
      return unless schedule

      (0..6).each do |wday|
        day_params = days[wday.to_s]
        enabled = day_params.is_a?(Hash) && day_params["enabled"].to_s == "1"
        opens_at = day_params["opens_at"].presence if day_params.is_a?(Hash)
        closes_at = day_params["closes_at"].presence if day_params.is_a?(Hash)

        window = schedule.availability_windows.find_by(weekday: wday)

        if enabled && opens_at.present? && closes_at.present?
          parsed_opens = Time.zone.parse("2000-01-01 #{opens_at}") rescue nil
          parsed_closes = Time.zone.parse("2000-01-01 #{closes_at}") rescue nil
          if parsed_opens && parsed_closes && parsed_closes > parsed_opens
            window ||= schedule.availability_windows.build(weekday: wday)
            window.update!(opens_at: parsed_opens, closes_at: parsed_closes)
          end
        elsif window.present?
          window.destroy!
        end
      end
    end
  end
end
