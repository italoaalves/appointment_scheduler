# frozen_string_literal: true

module Spaces
  class CustomersController < Spaces::BaseController
    include RequirePermission

    require_permission :manage_customers, except: [ :index, :show ], redirect_to: :customers_path
    before_action :set_customer, only: [ :show, :edit, :update, :destroy ]

    def index
      base = current_tenant.customers.order(:name)
      if params[:query].present?
        sanitized = ActiveRecord::Base.sanitize_sql_like(params[:query].strip)
        base = base.where("name ILIKE ?", "%#{sanitized}%")
      end
      @customers = base.page(params[:page]).per(20)
      @grouped_customers = @customers.group_by { |c| c.name[0]&.upcase || "#" }
    end

    def show
      @appointments = @customer.appointments
                               .includes(:space)
                               .where.not(status: :cancelled)
                               .order(scheduled_at: :desc)
                               .page(params[:page])
                               .per(10)
    end

    def new
      @customer = current_tenant.customers.build
    end

    def create
      unless Billing::PlanEnforcer.can?(current_tenant, :create_customer)
        redirect_to customers_path, alert: t("billing.limits.customers_exceeded") and return
      end
      @customer = current_tenant.customers.build(customer_params)

      if @customer.save
        redirect_to customer_path(@customer)
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @customer.update(customer_params)
        redirect_to customer_path(@customer)
      else
        render :edit
      end
    end

    def destroy
      active_count = @customer.appointments.where(status: Appointment::SLOT_BLOCKING_STATUSES).count
      if active_count > 0
        message = t("space.customers.destroy.has_active_appointments", count: active_count)
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(ActionView::RecordIdentifier.dom_id(@customer),
                partial: "spaces/customers/customer",
                locals: { customer: @customer, shake: true }),
              turbo_stream.replace("modal_container",
                partial: "shared/error_modal",
                locals: { message: message })
            ]
          end
          format.html { redirect_to customers_path, alert: message }
        end
        return
      end

      @customer.destroy
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.remove(ActionView::RecordIdentifier.dom_id(@customer)) }
        format.html { redirect_to customers_path }
      end
    end

    private

    def set_customer
      @customer = current_tenant.customers.find(params[:id])
    end

    def customer_params
      params.require(:customer).permit(:name, :phone, :address, :email)
    end
  end
end
