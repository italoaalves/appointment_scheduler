# frozen_string_literal: true

module Platform
  class PlansController < Platform::BaseController
    before_action :set_plan, only: [ :show, :edit, :update ]

    def index
      @plans = Billing::Plan.order(:position)
    end

    def show
      redirect_to edit_platform_plan_path(@plan)
    end

    def new
      @plan = Billing::Plan.new
    end

    def create
      @plan = Billing::Plan.new(plan_params)

      save_with_trial_default_handling(:new)
    end

    def edit
    end

    def update
      @plan.assign_attributes(plan_params_for_update)

      save_with_trial_default_handling(:edit)
    end

    private

    def set_plan
      @plan = Billing::Plan.find(params[:id])
    end

    def plan_params
      normalize_limits(
        params.require(:billing_plan).permit(
          :name, :slug, :price_cents,
          :max_team_members, :max_customers, :max_scheduling_links,
          :whatsapp_monthly_quota, :position, :public, :highlighted,
          :trial_default, :active,
          features: [], allowed_payment_methods: []
        )
      )
    end

    # Slug is immutable after creation — strip it from update params.
    def plan_params_for_update
      plan_params.except(:slug)
    end

    # Convert blank limit strings to nil so nil = unlimited is preserved.
    def normalize_limits(permitted)
      %i[max_team_members max_customers max_scheduling_links whatsapp_monthly_quota].each do |field|
        permitted[field] = nil if permitted[field].blank?
      end
      permitted
    end

    # Wraps save in a transaction that clears any existing trial_default
    # before setting a new one, avoiding the unique partial index violation.
    def save_with_trial_default_handling(render_action)
      Billing::Plan.transaction do
        if @plan.trial_default?
          Billing::Plan.where.not(id: @plan.id).where(trial_default: true)
                       .update_all(trial_default: false)
        end

        if @plan.save
          redirect_to platform_plans_path, notice: t("platform.plans.#{render_action == :new ? 'create' : 'update'}.notice")
        else
          render render_action, status: :unprocessable_entity
          raise ActiveRecord::Rollback
        end
      end
    end
  end
end
